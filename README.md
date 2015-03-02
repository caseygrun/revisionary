revisionary
===========

Generic interface to versioned file storage in JavaScript. Currently provides an engine for `git`.

```coffeescript
revisionary = require('revisionary')
store = revisionary.Store.create('git', 'test_repo')

store.initialize null, (err) ->
    if err? then throw err

    author = new revisionary.Author('Example User', 'example.user@example.com')
    store.save 'foo.txt', 'Hello world!', author, 'Creating a new file for the demo', (err, resource) ->
        if err? then throw err
        
        console.log resource
        # { path: 'foo.txt', contents: 'Hello world!', latest: null }

        store.log 'foo.txt', (err, revisions) ->
            if err? then throw err

            console.log revisions
            # [ { path: 'foo.txt',
            #   id: '3a544e54b382faef84d71159e86103327a29d78f',
            #   time: Mon Mar 02 2015 00:04:50 GMT+0000 (UTC),
            #   author: { name: 'Example User', email: 'example.user@example.com' },
            #   message: 'Creating a new file for the demo',
            #   changes: [] } ]
```

See the [tests](tests.coffee) for more examples.

Inspired by [John MacFarlane](johnmacfarlane.net/)'s [filestore](https://github.com/jgm/filestore)