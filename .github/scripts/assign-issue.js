const { Octokit } = require('@octokit/rest');

// Create an Octokit instance using the GitHub token
const octokit = new Octokit({
  auth: process.env.ADD_TO_PROJECT_PAT,
});

async function assignIssueToCommentAuthor(issueNumber, commentAuthor) {
  try {
    // Get the issue details
    const { data: issue } = await octokit.issues.get({
      owner: 'your-repo-owner',
      repo: 'your-repo-name',
      issue_number: issueNumber,
    });

    // Assign the issue to the comment author
    await octokit.issues.update({
      owner: 'your-repo-owner',
      repo: 'your-repo-name',
      issue_number: issueNumber,
      assignees: [commentAuthor],
    });

    console.log(`Issue ${issueNumber} assigned to ${commentAuthor}`);
  } catch (error) {
    console.error('Error assigning issue:', error);
  }
}

// Extract information from the GitHub event payload
const issueNumber = process.env.GITHUB_EVENT.issue.number;
const commentAuthor = process.env.GITHUB_EVENT.comment.user.login;
const commentBody = process.env.GITHUB_EVENT.comment.body;

// Check if the comment contains the "/assign" keyword
if (commentBody.includes('/assign')) {
  // Call the function to assign the issue
  assignIssueToCommentAuthor(issueNumber, commentAuthor);
} else {
  console.log('Comment does not contain /assign keyword. Issue will not be assigned.');
}
