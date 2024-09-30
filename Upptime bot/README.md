# Upptime bot

This tool will help monitor deployed services to see if they are up or not

[Upptime](https://upptime.js.org/)

## Setup

### Fork repository

Create a public repository (so you are not billed for github actions) and create a repo using [this template](https://github.com/upptime/upptime/generate) in [GitHub](https://github.com)

### Enable repository publishing

1. Go to your repository settings page
2. Go to the "Pages" sub-section on the left
3. Under "Source", change "None" to "Deploy from a branch"
4. In the Branch dropdown, select gh-pages and /(root)
5. Click on "Save"

### Generate and add github access token to repository

1. Click on your profile picture on the top-right corner and select "Settings"
2. In the left sidebar, select "Developer settings"
3. In the left sidebar, click "Personal access tokens" > "Fine-grained tokens"
4. Click "Generate new token"
5. Give your token a specific distinct name
6. In the "Expiration" dropdown, select "90 days" or a custom, longer expiry
7. In the "Resource Owner" section select the user or organization your Upptime repository belongs to
8. In the "Repository Access" section select "Only select repositories" and select your Upptime repository
9. In the "Permissions" > "Repository permissions" section enable read-write access to Actions, Contents, Issues and Workflows
10. Skip the "Organization permissions" section
11. Click "Generate token" or "Generate token and request access" (if it is in an org you are not an admin of)
    After generating your token, copy it (you will not see it again). Then, add it as a repository secret:
12. In your Upptime repository, select "Settings"
13. In the left sidebar, click "Secrets and variables" followed by "Actions"
14. Press the button "New repository secret"
15. Enter the name of the secret as GH_PAT
16. Paste your personal access token into the Value field
17. Be sure there are no spaces before or after the token and/or linebreaks after your token
18. Save your PAT by selecting "Add secret"

## Configuration

### Sites to check

Below is a template of all the thigns you can monitor

**Remember that all github secrets letters are uperclass meaning a secret named google will be use able as GOOGLE in script**
**Remember that if your url is not http or https you should specify check and port**
sites:
    - name: Displayed name in status board
      check: "tcp-ping"
      # hostname or  ip or https site or github secret containing an ip https site or https with path example
      url: dns.google
      url: 8.8.8.8
      url: https://google.com
      url: https://example.com/get-user/3?api_key=$MY_API_KEY

      # Set request headers under headers as key value pair example"
      headers:
        - "Authorization: Bearer $SECRET_SITE_2"
        - "Content-Type: application/json"

      # Send data with headers in body
      body: '{ "password": "hello" }'

      # make http request
      method: POST
      method: DELETE
      # Set custom icon
      icon: https://www.google.com/favicon.ico
      # Set expected status codes so that if you get these codes the site will apear as top
      expectedStatusCodes:
        - 200
        - 201
        - 404
      # Set a time to waite for respone default is 30 seconds more than that and the performance is degraded
      maxResponseTime: 5000

### Notification

To see the documentation click [here](https://upptime.js.org/docs/notifications)

### Uptime site

To see the settings related to uptime site click [here](https://upptime.js.org/docs/configuration#status-website)
To add a custom domain to github see [here](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages#verifying-a-domain-for-your-user-site) to verify your site and see [here](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site#configuring-a-subdomain) to add your site to github pages

status-website:
  theme: light
  themeUrl: https://example.com/my-custom-theme.css
  #Site title
  name: Upptime
  #Site logo
  logoUrl: https://example.com/image.jpg
  #You can set a custom cname
  cname: upptime.js.org # Custom CNAME
  baseUrl: /repo # where "repo" is your repository name if you are not using a CNAME
  navbar:
    - title: Status
      href: /
    - title: GitHub
      href: https://github.com/$OWNER/$REPO
