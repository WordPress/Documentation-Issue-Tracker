# Fixing `_load_textdomain_just_in_time` Warning in WordPress 6.8+

In WordPress 6.7 and above, you may encounter the following warning:

```
Notice: Function _load_textdomain_just_in_time was called incorrectly.
```

### Why this happens?

This warning appears when translation files are loaded too early—before the `init` hook. It usually happens when a plugin or theme tries to load translations directly on plugin/theme load.

### ✅ Correct Way to Load Translations

#### For Plugins:
```php
add_action( 'init', 'load_myplugin_textdomain' );
function load_myplugin_textdomain() {
    load_plugin_textdomain( 'myplugin', false, dirname( plugin_basename( __FILE__ ) ) . '/languages' );
}
```

#### For Themes:
```php
add_action( 'after_setup_theme', 'load_mytheme_textdomain' );
function load_mytheme_textdomain() {
    load_theme_textdomain( 'mytheme', get_template_directory() . '/languages' );
}
```

🚫 Avoid using `_load_textdomain_just_in_time()` directly.

### References:
- https://core.trac.wordpress.org/ticket/63185
- https://developer.wordpress.org/plugins/internationalization/how-to-internationalize-your-plugin/
