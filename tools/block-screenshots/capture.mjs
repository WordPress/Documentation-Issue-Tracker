// Retakes the screenshots of a HelpHub block article in a throwaway WordPress
// Playground instance, so no local WordPress install is needed.
//
// Usage: node capture.mjs <config.json> [out-dir]
// See README.md and examples/ for the config format.
import { spawn } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { chromium } from 'playwright';

const configPath = process.argv[ 2 ];
if ( ! configPath ) {
	console.error( 'Usage: node capture.mjs <config.json> [out-dir]' );
	process.exit( 1 );
}
const config = JSON.parse( readFileSync( configPath, 'utf8' ) );
const outDir = process.argv[ 3 ] || join( 'out', basename( configPath, '.json' ) );
mkdirSync( outDir, { recursive: true } );

const PORT = 9400;
const BASE = `http://127.0.0.1:${ PORT }`;
const OPEN_ID = 1001;
const CLOSED_ID = 1002;
const VIEWPORT = { width: 1280, height: 1150 };

// Blueprint: the theme, and two posts holding the block (comments open and closed).
const post = ( id, title, status ) => `wp_insert_post( array(
	'import_id' => ${ id }, 'post_title' => ${ JSON.stringify( title ) }, 'post_status' => 'publish',
	'comment_status' => '${ status }', 'post_content' => ${ JSON.stringify( config.content ) },
) );`;
const blueprint = {
	steps: [
		{ step: 'activateTheme', themeFolderName: config.theme || 'twentytwentyfive' },
		{
			step: 'runPHP',
			code: `<?php require '/wordpress/wp-load.php';
${ post( OPEN_ID, 'Sample post', 'open' ) }
${ post( CLOSED_ID, 'Comments closed post', 'closed' ) }`,
		},
	],
};
const blueprintPath = join( outDir, 'blueprint.json' );
writeFileSync( blueprintPath, JSON.stringify( blueprint, null, '\t' ) );

console.log( `Starting WordPress ${ config.wp || 'latest' } in Playground ...` );
const server = spawn( 'npx', [
	'wp-playground-cli', 'server', `--port=${ PORT }`, `--wp=${ config.wp || 'latest' }`,
	`--blueprint=${ blueprintPath }`, '--login',
], { stdio: [ 'ignore', 'pipe', 'inherit' ], shell: process.platform === 'win32' } );
const stop = () => server.kill();
process.on( 'exit', stop );

// The CLI prints its URL before the blueprint has finished, so wait until WordPress answers.
server.stdout.on( 'data', ( chunk ) => process.env.DEBUG && process.stdout.write( chunk ) );
server.on( 'exit', ( code ) => {
	console.error( `Playground exited with code ${ code }.` );
	process.exit( 1 );
} );
for ( let waited = 0; ; waited += 3 ) {
	const ok = await fetch( `${ BASE }/wp-json/` ).then( ( r ) => r.ok ).catch( () => false );
	if ( ok ) break;
	if ( waited > 300 ) throw new Error( 'Playground did not start within 5 minutes.' );
	await new Promise( ( r ) => setTimeout( r, 3000 ) );
}
console.log( 'WordPress is ready.' );

const browser = await chromium.launch();
const page = await browser.newPage( { viewport: VIEWPORT, deviceScaleFactor: 2 } );
page.setDefaultTimeout( 120000 );

async function openEditor( id ) {
	await page.goto( `${ BASE }/wp-admin/post.php?post=${ id }&action=edit` );
	if ( new URL( page.url() ).pathname !== '/wp-admin/post.php' ) {
		throw new Error( `Expected the editor but landed on ${ page.url() }` );
	}
	await page.waitForFunction( () => window.wp?.data?.select( 'core/block-editor' )?.getBlocks().length > 0 ).catch( async ( e ) => {
		const text = ( await page.locator( 'body' ).innerText().catch( () => '' ) ).replace( /\s+/g, ' ' ).slice( 0, 300 );
		throw new Error( `The editor did not load post ${ id }. Page says: ${ text }` );
	} );
	await page.evaluate( () => {
		const prefs = window.wp.data.dispatch( 'core/preferences' );
		prefs.set( 'core/edit-post', 'welcomeGuide', false );
		prefs.set( 'core', 'fixedToolbar', false );
	} );
	await page.keyboard.press( 'Escape' );
	await page.waitForTimeout( 1500 );
}

// Selecting through the data store is more reliable than clicking into the canvas.
async function selectBlock() {
	await page.evaluate( ( name ) => {
		const { select, dispatch } = window.wp.data;
		const find = ( blocks ) => {
			for ( const b of blocks ) {
				if ( b.name === name ) return b.clientId;
				const inner = find( b.innerBlocks );
				if ( inner ) return inner;
			}
		};
		dispatch( 'core/block-editor' ).selectBlock( find( select( 'core/block-editor' ).getBlocks() ) );
	}, config.block );
	await page.waitForTimeout( 1200 );
}

// Screenshot of the area spanning all the given locators, plus padding.
async function shot( name, locators, pad = 16 ) {
	const boxes = [];
	for ( const l of locators ) {
		const b = await l.boundingBox().catch( () => null );
		if ( b ) boxes.push( b );
	}
	if ( ! boxes.length ) throw new Error( 'nothing to capture' );
	const x = Math.max( 0, Math.min( ...boxes.map( ( b ) => b.x ) ) - pad );
	const y = Math.max( 0, Math.min( ...boxes.map( ( b ) => b.y ) ) - pad );
	const right = Math.min( VIEWPORT.width, Math.max( ...boxes.map( ( b ) => b.x + b.width ) ) + pad );
	const bottom = Math.min( VIEWPORT.height, Math.max( ...boxes.map( ( b ) => b.y + b.height ) ) + pad );
	const file = join( outDir, `${ name }.png` );
	await page.screenshot( { path: file, clip: { x, y, width: right - x, height: bottom - y } } );
	console.log( `  saved ${ file }` );
}

const toolbar = () => page.locator( '.block-editor-block-contextual-toolbar, .block-editor-block-toolbar' ).first();
const blockClass = `.wp-block-${ config.block.replace( /^core\//, '' ).replace( '/', '-' ) }`;
const blockInCanvas = () => page.frameLocator( 'iframe[name="editor-canvas"]' ).locator( blockClass ).first();

// Each shot opens its menu (if any), then captures the toolbar together with it.
const SHOTS = {
	block: async () => {
		await selectBlock();
		await blockInCanvas().scrollIntoViewIfNeeded();
		await selectBlock();
		await shot( 'block', [ blockInCanvas(), toolbar() ] );
	},
	inserter: async () => {
		// Found by accessible name: the toggle's class has changed between releases.
		await page.locator( 'body' ).click( { position: { x: 640, y: 10 } } ).catch( () => {} );
		const toggle = page.getByRole( 'button', { name: /block inserter/i } ).first();
		await toggle.click();
		await page.locator( '.block-editor-inserter__search input' ).fill( config.search );
		await page.locator( '.block-editor-inserter__main-area .components-spinner' ).waitFor( { state: 'detached', timeout: 60000 } ).catch( () => {} );
		await page.waitForTimeout( 1500 );
		await shot( 'inserter', [ page.locator( '.block-editor-inserter__search' ).first(), page.locator( '.block-editor-block-types-list' ).first() ], 12 );
		await toggle.click();
	},
	toolbar: async () => {
		await selectBlock();
		await shot( 'toolbar', [ toolbar() ], 8 );
	},
	transform: async () => {
		await selectBlock();
		await page.locator( '.block-editor-block-toolbar .block-editor-block-switcher button' ).first().click();
		await page.waitForTimeout( 800 );
		await shot( 'transform', [ toolbar(), page.locator( '.block-editor-block-switcher__popover .components-popover__content' ).first() ] );
	},
	movers: async () => {
		await selectBlock();
		await shot( 'movers', [ page.locator( '.block-editor-block-mover' ).first() ], 8 );
	},
	align: async () => {
		await selectBlock();
		await page.locator( '.block-editor-block-toolbar button[aria-label="Align text"]' ).first().click();
		await page.waitForTimeout( 800 );
		await shot( 'align', [ toolbar(), page.locator( '.components-dropdown-menu__menu' ).first() ] );
	},
	options: async () => {
		await selectBlock();
		await page.locator( '.block-editor-block-toolbar button[aria-label="Options"]' ).first().click();
		await page.waitForTimeout( 800 );
		await shot( 'options', [ toolbar(), page.locator( '.block-editor-block-settings-menu__popover .components-popover__content, .components-dropdown-menu__menu' ).first() ] );
	},
	'comments-closed': async () => {
		await openEditor( CLOSED_ID );
		await selectBlock();
		await blockInCanvas().scrollIntoViewIfNeeded();
		await selectBlock();
		await shot( 'comments-closed', [ blockInCanvas(), toolbar() ] );
		await openEditor( OPEN_ID );
	},
};

// The CLI's --login only covers its own browser session; log this one in too.
async function logIn() {
	await page.goto( `${ BASE }/wp-login.php` );
	await page.fill( '#user_login', 'admin' );
	await page.fill( '#user_pass', 'password' );
	await Promise.all( [ page.waitForURL( /wp-admin/, { waitUntil: 'commit' } ), page.click( '#wp-submit' ) ] );
}

let failed = 0;
try {
	await logIn();
	await openEditor( OPEN_ID );
	for ( const name of config.shots ) {
		if ( ! SHOTS[ name ] ) {
			console.log( `  unknown shot "${ name }", skipped` );
			continue;
		}
		try {
			await SHOTS[ name ]();
		} catch ( e ) {
			failed++;
			console.log( `  ${ name } FAILED: ${ e.message.split( '\n' )[ 0 ] }` );
		}
		await page.keyboard.press( 'Escape' ).catch( () => {} );
	}
} finally {
	await browser.close();
	stop();
}
console.log( failed ? `Done with ${ failed } failed shot(s).` : `Done. Screenshots are in ${ outDir }` );
process.exit( failed ? 1 : 0 );
