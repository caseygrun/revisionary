// Generated by CoffeeScript 1.9.1
(function() {
  var GitStore, async, buffertools, child_process, fs, git, mkdirp, pth, q, rimraf, store, utils;

  q = QUnit;

  mkdirp = require('mkdirp');

  rimraf = require('rimraf');

  async = require('async');

  child_process = require('child_process');

  buffertools = require('buffertools');

  pth = require('path');

  fs = require('fs');

  q.module('utils');

  utils = require('../utils');

  q.test('sanitizeShellString', function() {
    q.equal(utils.sanitizeShellString("rm -rf"), "'rm -rf'");
    q.equal(utils.sanitizeShellString(" what's up "), "' what\\'s up '");
    return q.equal(utils.sanitizeShellString("hello\\world"), "'hello\\\\world'");
  });

  q.test('sanitizePath', function() {
    q.equal(utils.sanitizePath("/../"), "/", ".. and // removed sequentially");
    q.equal(utils.sanitizePath("wh!@#$%^&*()+<>,?:;[]{}\'\"\\t"), 'wht', "non-word characters removed");
    q.equal(utils.sanitizePath('../wh!t'), '/wht', ".. and non-word characters removed");
    return q.equal(utils.sanitizePath('./a/valid/path.txt'), './a/valid/path.txt', "valid path is passed unchanged");
  });

  git = false;

  GitStore = require('../git');

  store = require('../core');

  q.module('git', {
    'setup': function() {
      rimraf.sync('test_repo');
      mkdirp.sync('test_repo');
      git = new GitStore('test_repo');
      q.stop();
      return git.initialize(null, function(err) {
        return q.start();
      });
    },
    'teardown': function() {}
  });

  q.test('init', function() {
    q.expect(1);
    q.stop();
    child_process.exec('git status', {
      cwd: 'test_repo'
    }, function(err, stdout, stderr) {
      q.equal("# On branch master\n#\n# Initial commit\n#\nnothing to commit (create/copy files and use \"git add\" to track)\n", stdout);
      return q.start();
    });
    return true;
  });

  q.test('parseCommit', function() {
    var date, email, hash, msg, name, parsedCommit, path, testString, time;
    hash = "8048d56e64d4325166b0f3bd756db155b0155cb6";
    name = "Name";
    email = "Email@email.com";
    time = "1375222059";
    msg = "Test create commit";
    path = "/test/hello.txt";
    date = new Date(parseInt(time) * 1000);
    testString = hash + "\x00" + name + "\x00" + email + "\x00" + time + "\x00" + msg;
    parsedCommit = git.parseCommit(testString);
    return q.deepEqual([hash, name, email, date, msg], parsedCommit, 'Parsed commit has correct fields');
  });

  q.test('commitRevision', function() {
    var date, email, hash, msg, name, parsedCommit, parsedLog, path, testString, time;
    hash = "8048d56e64d4325166b0f3bd756db155b0155cb6";
    name = "Name";
    email = "Email@email.com";
    time = "1375222059";
    msg = "Test create commit";
    path = "/test/hello.txt";
    date = new Date(parseInt(time) * 1000);
    testString = hash + "\x00" + name + "\x00" + email + "\x00" + time + "\x00" + msg;
    parsedCommit = git.parseCommit(testString);
    parsedLog = git.commitRevision(path, parsedCommit);
    q.ok(parsedLog != null, 'A log string is parsed');
    q.equal(parsedLog.path, path, 'Path is correct');
    q.equal(parsedLog.id, hash, 'Hash is correct');
    q.equal(parsedLog.time.toString(), date.toString(), 'Time is correct');
    q.equal(parsedLog.message, msg, 'Message is correct');
    q.equal(parsedLog.author.name, name, 'Author name is correct');
    return q.equal(parsedLog.author.email, email, 'Author email is correct');
  });

  q.test('parseLogLines', function() {
    var expected, expectedRevs, i, j, len, logText, results1, rev, revs;
    logText = "6b211e61fb9192cdbb68fb9e3162152861217691\x00Name2\x00Email2@example.com\x001383023629\x00Test save commit\n\ntestLogDir/saveTest.txt\n\n0da471f7226f1db0b2fc6307c7f1ec7b4f9c108c\x00Name\x00Email@example.com\x001383023628\x00Test create commit\n\ntestLogDir/saveTest.txt";
    expectedRevs = [
      {
        path: 'testLogDir/saveTest.txt',
        id: '6b211e61fb9192cdbb68fb9e3162152861217691',
        author: {
          name: 'Name2',
          email: 'Email2@example.com'
        },
        message: 'Test save commit',
        changes: []
      }, {
        path: 'testLogDir/saveTest.txt',
        id: '0da471f7226f1db0b2fc6307c7f1ec7b4f9c108c',
        author: {
          name: 'Name',
          email: 'Email@example.com'
        },
        message: 'Test create commit',
        changes: []
      }
    ];
    revs = git.parseLogLines(logText);
    q.ok(revs, 'Lines are returned');
    results1 = [];
    for (i = j = 0, len = revs.length; j < len; i = ++j) {
      rev = revs[i];
      expected = expectedRevs[i];
      q.equal(rev.path, expected.path, "Path " + i + " is correct");
      q.equal(rev.author.name, expected.author.name, "Author name " + i + " is correct");
      q.equal(rev.author.email, expected.author.email, "Author email " + i + " is correct");
      q.equal(rev.message, expected.message, "Message " + i + " is correct");
      q.ok(rev.id, "ID " + i + " exists");
      results1.push(q.ok(rev.time, "Time " + i + " exists"));
    }
    return results1;
  });

  q.test('create', function() {
    var createAuthor, createMessage, createPath1, createPath2, createPath3, createText;
    q.expect(5);
    createPath1 = 'createTest.txt';
    createPath2 = 'space test.txt';
    createPath3 = 'folder/test.txt';
    createText = 'hello world';
    createAuthor = new store.Author('Name', 'Email@email.com');
    createMessage = 'Test create commit';
    q.stop();
    return async.series([
      function(callback) {
        return git.create(createPath1, createText, createAuthor, createMessage, function(err, returnedResource) {
          q.ok(err == null, 'No error on creating file 1');
          if (err != null) {
            console.log(err);
          }
          return async.parallel([
            function(cb) {
              return git.read(createPath1, null, function(err, retrievedResourceText) {
                q.equal(retrievedResourceText, createText, 'Created file has proper contents');
                if (err != null) {
                  console.log(err);
                }
                return cb(err);
              });
            }, function(cb) {
              return git.latest(createPath1, function(err, returnedRevision) {
                q.ok(returnedRevision, 'A revision is returned');
                return cb(null);
              });
            }
          ], function(err) {
            return callback();
          });
        });
      }, function(callback) {
        return git.create(createPath2, createText, createAuthor, createMessage, function(err, returnedResource) {
          q.ok(err == null, 'No error on creating file 2');
          if (err != null) {
            console.log(err);
          }
          return callback();
        });
      }, function(callback) {
        return git.create(createPath3, createText, createAuthor, createMessage, function(err, returnedResource) {
          q.ok(err == null, 'No error on creating file 3');
          if (err != null) {
            console.log(err);
          }
          return callback();
        });
      }
    ], function(err) {
      return q.start();
    });
  });

  q.test('save', function() {
    var createAuthor, createMessage, createPath, createText, saveAuthor, saveMessage, savePath, saveText;
    q.expect(9);
    createPath = savePath = 'saveTest.txt';
    createText = 'hello world';
    createAuthor = new store.Author('Name', 'Email@example.com');
    createMessage = 'Test create commit';
    saveText = 'hello new world';
    saveAuthor = new store.Author('Name2', 'Email2@example.com');
    saveMessage = 'Test save commit';
    q.stop();
    return git.create(createPath, createText, createAuthor, createMessage, function(err, returnedResource) {
      q.ok(err == null, 'No error on creating file');
      if (err != null) {
        return console.log(err);
      }
      return git.save(savePath, saveText, saveAuthor, saveMessage, function(err, returnedResource) {
        return async.parallel([
          function(cb) {
            return git.read(savePath, null, function(err, retrievedResourceText) {
              q.equal(retrievedResourceText, saveText, 'Created file has proper contents');
              if (err != null) {
                console.log(err);
              }
              return cb(err);
            });
          }, function(cb) {
            return git.latest(savePath, function(err, returnedRevision) {
              q.ok(err == null, 'No error on retrieving revision');
              q.ok(returnedRevision != null, 'A revision is returned');
              q.equal(returnedRevision.author.name, saveAuthor.name, 'Author name is correct');
              q.equal(returnedRevision.author.email, saveAuthor.email, 'Author email is correct');
              q.ok(returnedRevision.id != null, 'Revision is assigned an ID');
              q.ok(returnedRevision.time != null, 'Revision is assigned a date');
              q.equal(returnedRevision.message, saveMessage, 'Save message is correct');
              return cb(null);
            });
          }
        ], function(err) {
          return q.start();
        });
      });
    });
  });

  q.test('move', function() {
    var createAuthor, createMessage, createPath, createText, moveAuthor, moveMessage, movePath;
    q.expect(11);
    createPath = 'moveTest.txt';
    createText = 'hello world';
    createAuthor = new store.Author('Name', 'Email@example.com');
    createMessage = 'Test create commit';
    movePath = 'moved.txt';
    moveAuthor = createAuthor;
    moveMessage = 'Moved file';
    q.stop();
    return git.create(createPath, createText, createAuthor, createMessage, function(err, returnedResource) {
      q.ok(err == null, 'No error on creating file');
      if (err != null) {
        return console.log(err);
      }
      return git.move(createPath, movePath, moveAuthor, moveMessage, function(err) {
        q.ok(err == null, 'No error in moving file');
        return async.parallel([
          function(cb) {
            return git.read(movePath, null, function(err, retrievedResourceText) {
              q.ok(err == null, 'No error on retrieving resource');
              q.equal(retrievedResourceText, createText, 'Moved file has proper contents');
              if (err != null) {
                console.log(err);
              }
              return cb(err);
            });
          }, function(cb) {
            return git.latest(movePath, function(err, returnedRevision) {
              q.ok(err == null, 'No error on retrieving revision');
              q.ok(returnedRevision != null, 'A revision is returned');
              q.equal(returnedRevision.author.name, moveAuthor.name, 'Author name is correct');
              q.equal(returnedRevision.author.email, moveAuthor.email, 'Author email is correct');
              q.ok(returnedRevision.id != null, 'Revision is assigned an ID');
              q.ok(returnedRevision.time != null, 'Revision is assigned a date');
              q.equal(returnedRevision.message, moveMessage, 'Move message is correct');
              return cb(null);
            });
          }
        ], function(err) {
          return q.start();
        });
      });
    });
  });

  q.test('remove', function() {
    var createAuthor, createMessage, createPath, createText, removeAuthor, removeMessage, removePath;
    q.expect(11);
    createPath = removePath = 'removeTest.txt';
    createText = 'hello world';
    createAuthor = new store.Author('Name', 'Email@example.com');
    createMessage = 'Test create commit';
    removeAuthor = createAuthor;
    removeMessage = 'Removed file';
    q.stop();
    return git.create(createPath, createText, createAuthor, createMessage, function(err, returnedResource) {
      q.ok(err == null, 'No error on creating file');
      if (err != null) {
        return console.log(err);
      }
      return git.remove(removePath, removeAuthor, removeMessage, function(err) {
        q.ok(err == null, 'No error in removing file');
        return async.parallel([
          function(cb) {
            return git.exists(removePath, function(err, exist) {
              q.ok(!exist, 'File no longer exists');
              return cb(null);
            });
          }, function(cb) {
            return git.latest(removePath, function(err, returnedRevision) {
              q.ok(err == null, 'No error on retrieving revision');
              q.ok(returnedRevision != null, 'A revision is returned');
              q.equal(returnedRevision.author.name, removeAuthor.name, 'Author name is correct');
              q.equal(returnedRevision.author.email, removeAuthor.email, 'Author email is correct');
              q.ok(returnedRevision.id != null, 'Revision is assigned an ID');
              q.ok(returnedRevision.time != null, 'Revision is assigned a date');
              q.equal(returnedRevision.message, removeMessage, 'Move message is correct');
              return cb(null);
            });
          }
        ], function(err) {
          return q.start();
        });
      });
    });
  });

  q.test('read', function() {
    var createAuthor, createMessage, createPath, inputPath, savePath;
    inputPath = 'tests/lab.jpg';
    createPath = savePath = 'testImage.jpg';
    createAuthor = new store.Author('Name', 'Email@example.com');
    createMessage = 'Test commit for image file';
    q.stop();
    return fs.readFile(inputPath, function(err, data) {
      q.ok(!(typeof err === "function" ? err('No error on reading input file') : void 0));
      if (err) {
        console.log(err);
      }
      return git.create(createPath, data, createAuthor, createMessage, function(err, returnedResource) {
        q.ok(err == null, 'No error on creating file');
        if (err) {
          console.log(err);
        }
        return git.read(createPath, {
          encoding: 'buffer',
          maxBuffer: 20000 * 1024
        }, function(err, readData) {
          q.ok(!(typeof err === "function" ? err('No error on reading output file') : void 0));
          if (err) {
            console.log(err);
          }
          q.ok(buffertools.equals(data, readData), 'Output file is the same');
          return q.start();
        });
      });
    });
  });

  q.test('log', function() {
    var createAuthor, createDate, createMessage, createPath, createText, saveAuthor, saveMessage, savePath, saveText;
    createPath = savePath = 'testLogDir/saveTest.txt';
    createText = 'hello world';
    createAuthor = new store.Author('Name', 'Email@example.com');
    createMessage = 'Test create commit';
    saveText = 'hello new world';
    saveAuthor = new store.Author('Name2', 'Email2@example.com');
    saveMessage = 'Test save commit';
    createDate = false;
    q.stop();
    return git.create(createPath, createText, createAuthor, createMessage, function(err, returnedResource) {
      var doSave;
      q.ok(err == null, 'No error on creating file');
      if (err != null) {
        return console.log(err);
      }
      createDate = new Date();
      createDate.setSeconds(createDate.getSeconds() + 1);
      doSave = function() {
        return git.save(savePath, saveText, saveAuthor, saveMessage, function(err, returnedResource) {
          q.ok(err == null, 'No error on saving file');
          return async.series([
            function(cb) {
              return git.log(savePath, function(err, results) {
                var ref, ref1, ref10, ref2, ref3, ref4, ref5, ref6, ref7, ref8, ref9;
                q.ok(err == null, 'No error on log');
                if (err) {
                  cb(err);
                }
                q.ok(results.length === 2, 'Two revisions are returned');
                q.ok(((ref = results[0]) != null ? ref.id : void 0) && ((ref1 = results[1]) != null ? ref1.id : void 0), 'Revisions have IDs');
                q.ok(((ref2 = results[0]) != null ? ref2.id : void 0) !== ((ref3 = results[1]) != null ? ref3.id : void 0), 'Revisions have distinct IDs');
                q.ok(((ref4 = results[0]) != null ? ref4.time : void 0) && ((ref5 = results[1]) != null ? ref5.time : void 0), 'Revisions have distinct times');
                q.ok(((ref6 = results[0]) != null ? ref6.time : void 0) > ((ref7 = results[1]) != null ? ref7.time : void 0), 'Latest revision comes first');
                q.equal(results[1].message, createMessage, 'Create message is correct');
                q.equal(results[0].message, saveMessage, 'Save message is correct');
                q.equal(results[1].author.toString(), createAuthor.toString(), 'Create author is correct');
                q.equal(results[0].author.toString(), saveAuthor.toString(), 'Save author is correct');
                q.ok((((ref9 = results[0]) != null ? ref9.path : void 0) === (ref8 = (ref10 = results[1]) != null ? ref10.path : void 0) && ref8 === createPath), 'Path is correct');
                return cb(null);
              });
            }, function(cb) {
              return git.log(savePath, {
                since: createDate.toString()
              }, function(err, results) {
                q.ok(err == null, 'Since: No error on log');
                if (err != null) {
                  cb(err);
                }
                q.ok(results.length === 1, 'Since: One revision is returned');
                q.equal(results[0].message, saveMessage, 'Since: Save message is correct');
                return cb(null);
              });
            }, function(cb) {
              return git.log(savePath, {
                until: createDate.toString()
              }, function(err, results) {
                q.ok(err == null, 'Until: No error on log');
                if (err != null) {
                  cb(err);
                }
                q.ok(results.length === 1, 'Until: One revision is returned');
                q.equal(results[0].message, createMessage, 'Until: Create message is correct');
                return cb(null);
              });
            }
          ], function(err) {
            if (err) {
              console.log(err);
            }
            return q.start();
          });
        });
      };
      return setTimeout(doSave, 2000);
    });
  });

  q.test('list', function() {
    var createAuthor, createMessage, createText, dirPath, innerDir, testFile1, testFile2, testFile3, testFile4;
    q.expect(5);
    dirPath = 'testListDir';
    testFile1 = pth.join(dirPath, 'test 1.txt');
    testFile2 = pth.join(dirPath, 'test 2.txt');
    testFile3 = pth.join(dirPath, 'test 3.txt');
    innerDir = pth.join(dirPath, 'innerDir');
    testFile4 = pth.join(innerDir, 'test 4.txt');
    createText = 'hello world';
    createAuthor = new store.Author('Name', 'Email@example.com');
    createMessage = 'Test create commit';
    q.stop();
    return async.series([
      function(cb) {
        return git.create(testFile1, createText, createAuthor, createMessage, cb);
      }, function(cb) {
        return git.create(testFile2, createText, createAuthor, createMessage, cb);
      }, function(cb) {
        return git.create(testFile3, createText, createAuthor, createMessage, cb);
      }, function(cb) {
        return git.create(testFile4, createText, createAuthor, createMessage, cb);
      }
    ], function(err, results) {
      q.ok(err == null, 'No error on creating test files');
      return git.list(dirPath, function(err, resources) {
        var ref, ref1, ref2, ref3;
        resources.sort(function(a, b) {
          return a.path > b.path;
        });
        q.equal((ref = resources[1]) != null ? ref.path : void 0, testFile1, 'Test file 1 is present');
        q.equal((ref1 = resources[2]) != null ? ref1.path : void 0, testFile2, 'Test file 2 is present');
        q.equal((ref2 = resources[3]) != null ? ref2.path : void 0, testFile3, 'Test file 3 is present');
        q.equal((ref3 = resources[0]) != null ? ref3.path : void 0, innerDir + '/', 'Inner directory is present');
        return q.start();
      });
    });
  });

  q.test('all', function() {
    var createAuthor, createMessage, createText, dirPath, innerDir, testFile1, testFile2, testFile3, testFile4;
    q.expect(5);
    dirPath = 'testAllDir';
    testFile1 = pth.join(dirPath, 'test 1.txt');
    testFile2 = pth.join(dirPath, 'test 2.txt');
    testFile3 = pth.join(dirPath, 'test 3.txt');
    innerDir = pth.join(dirPath, 'innerDir');
    testFile4 = pth.join(innerDir, 'test 4.txt');
    createText = 'hello world';
    createAuthor = new store.Author('Name', 'Email@example.com');
    createMessage = 'Test create commit';
    q.stop();
    return async.series([
      function(cb) {
        return git.create(testFile1, createText, createAuthor, createMessage, cb);
      }, function(cb) {
        return git.create(testFile2, createText, createAuthor, createMessage, cb);
      }, function(cb) {
        return git.create(testFile3, createText, createAuthor, createMessage, cb);
      }, function(cb) {
        return git.create(testFile4, createText, createAuthor, createMessage, cb);
      }
    ], function(err, results) {
      q.ok(err == null, 'No error on creating test files');
      return git.all(dirPath, function(err, resources) {
        var ref, ref1, ref2, ref3;
        resources.sort(function(a, b) {
          return a.path > b.path;
        });
        q.equal((ref = resources[1]) != null ? ref.path : void 0, testFile1, 'Test file 1 is present');
        q.equal((ref1 = resources[2]) != null ? ref1.path : void 0, testFile2, 'Test file 2 is present');
        q.equal((ref2 = resources[3]) != null ? ref2.path : void 0, testFile3, 'Test file 3 is present');
        q.equal((ref3 = resources[0]) != null ? ref3.path : void 0, testFile4, 'Inner directory file is present');
        return q.start();
      });
    });
  });

  q.test('type', function() {
    var createAuthor, createMessage, createText, dirPath, testFile;
    q.expect(4);
    dirPath = 'testTypeDir';
    testFile = pth.join(dirPath, 'test1.txt');
    createText = 'hello world';
    createAuthor = new store.Author('Name', 'Email@example.com');
    createMessage = 'Test create commit';
    q.stop();
    return git.create(testFile, createText, createAuthor, createMessage, function(err, returnedResource) {
      q.ok(err == null, 'No error on creating test files');
      return async.series([
        function(cb) {
          return git.type(testFile, null, function(err, type) {
            q.equal(type, 'file', 'Type of file is properly detected');
            return cb(err);
          });
        }, function(cb) {
          return git.type(dirPath, null, function(err, type) {
            q.equal(type, 'folder', 'Type of folder is properly detected');
            return cb(err);
          });
        }
      ], function(err, results) {
        q.ok(err == null, 'No error in checking types of files and folder');
        if (err) {
          console.log(err);
        }
        return q.start();
      });
    });
  });

  q.test('search', function() {
    var createAuthor, createMessage, createText1, createText2, createText3, dirPath, testFile1, testFile2, testFile3;
    q.expect(8);
    dirPath = 'testSearchDir';
    testFile1 = pth.join(dirPath, 'test 1.txt');
    testFile2 = pth.join(dirPath, 'test 2.txt');
    testFile3 = pth.join(dirPath, '!@#$%^&*() test 3.txt');
    createText1 = 'hello world';
    createText2 = 'hello mother';
    createText3 = 'hello father';
    createAuthor = new store.Author('Name', 'Email@example.com');
    createMessage = 'Test create commit';
    q.stop();
    return async.series([
      function(cb) {
        return git.create(testFile1, createText1, createAuthor, createMessage, cb);
      }, function(cb) {
        return git.create(testFile2, createText2, createAuthor, createMessage, cb);
      }, function(cb) {
        return git.create(testFile3, createText3, createAuthor, createMessage, cb);
      }
    ], function(err, results) {
      q.ok(err == null, 'No error on creating test files');
      return git.search('mother', {}, function(err, matches) {
        var ref;
        q.ok(err == null, 'No error on searching for "mother"');
        q.ok(matches.length === 1, 'One match');
        q.equal((ref = matches[0][0]) != null ? ref.path : void 0, testFile2, 'Match has correct path');
        q.equal(matches[0][1], 1, 'Match has correct line number');
        q.equal(matches[0][2], createText2, 'Match has correct text');
        return git.search('sister', {}, function(err, matches) {
          q.ok(err == null, 'No error on searching for "sister"');
          q.deepEqual(matches, [], 'Missing phrase returns no matches');
          return q.start();
        });
      });
    });
  });

}).call(this);
