scarletquarry.vim
=================

Provides omnicomplete of redmine tickets in git commit messages.

```
git config redmine.url 'https://my.redmine.url'
git config redmine.apikey 'myapikey'
```

omnicompletion of issues is currently somewhat limited.
as the redmine api is extremely slow, a maximum of 100 issues is fetched.
