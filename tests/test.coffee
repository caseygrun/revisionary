if not QUnit? then QUnit = require('qunit-cli')
q = QUnit

mkdirp = require('mkdirp')
rimraf = require('rimraf')
async = require('async')
child_process = require('child_process')
pth = require('path')


q.module('utils');
utils = require('../utils');

q.test('sanitizeShellString',->
	q.equal(utils.sanitizeShellString("rm -rf"),"'rm -rf'")
	q.equal(utils.sanitizeShellString(" what's up "),"' what\\'s up '")
	q.equal(utils.sanitizeShellString("hello\\world"),"'hello\\\\world'")
)
q.test('sanitizePath',->
	q.equal(utils.sanitizePath("/../"),"/", ".. and // removed sequentially")
	q.equal(utils.sanitizePath("wh!@#$%^&*()+<>,?:;[]{}\'\"\\t"),'wht', "non-word characters removed")
	q.equal(utils.sanitizePath('../wh!t'),'/wht', ".. and non-word characters removed")
	q.equal(utils.sanitizePath('./a/valid/path.txt'),'./a/valid/path.txt', "valid path is passed unchanged")
)


git = false
gs = require('../git')
store = require('../store')
q.module('git',{
	'setup': -> 
		rimraf.sync('test_repo')
		mkdirp.sync('test_repo')
		git = new gs.GitStore('test_repo')
		q.stop()
		git.initialize(null,(err) ->
			q.start()
		)
	'teardown': ->
});

q.test('init',->
	q.expect(1)

	q.stop()
	child_process.exec('git status',{cwd: 'test_repo'},(err,stdout,stderr) ->
		q.equal("""# On branch master
				#
				# Initial commit
				#
				nothing to commit (create/copy files and use "git add" to track)

				""",stdout)
		q.start()
	)

	true
)

q.test('parseCommit',->
	hash = "8048d56e64d4325166b0f3bd756db155b0155cb6"
	name = "Name"
	email = "Email@email.com"
	time = "1375222059"
	msg = "Test create commit"
	path = "/test/hello.txt"
	date = new Date(parseInt(time)*1000)

	testString = "#{hash}\x00#{name}\x00#{email}\x00#{time}\x00#{msg}"
	
	parsedCommit = git.parseCommit(testString)

	q.deepEqual [hash, name, email, date, msg], parsedCommit, 'Parsed commit has correct fields'
)

q.test('commitRevision',->
	hash = "8048d56e64d4325166b0f3bd756db155b0155cb6"
	name = "Name"
	email = "Email@email.com"
	time = "1375222059"
	msg = "Test create commit"
	path = "/test/hello.txt"
	date = new Date(parseInt(time)*1000)

	testString = "#{hash}\x00#{name}\x00#{email}\x00#{time}\x00#{msg}"
	parsedCommit = git.parseCommit(testString) # [hash, name, email, date, msg]
	parsedLog = git.commitRevision(path,parsedCommit)

	q.ok(parsedLog?,'A log string is parsed')
	q.equal(parsedLog.path, path, 'Path is correct')
	q.equal(parsedLog.id, hash, 'Hash is correct')
	q.equal(parsedLog.time.toString(), date.toString(), 'Time is correct')
	q.equal(parsedLog.message, msg, 'Message is correct')

	q.equal(parsedLog.author.name, name, 'Author name is correct')
	q.equal(parsedLog.author.email, email, 'Author email is correct')
)

q.test('parseLogLines',->
	logText = """
	6b211e61fb9192cdbb68fb9e3162152861217691\x00Name2\x00Email2@example.com\x001383023629\x00Test save commit

	testLogDir/saveTest.txt

	0da471f7226f1db0b2fc6307c7f1ec7b4f9c108c\x00Name\x00Email@example.com\x001383023628\x00Test create commit

	testLogDir/saveTest.txt
	"""
	expectedRevs = [{ 
		path: 'testLogDir/saveTest.txt',
		id: '6b211e61fb9192cdbb68fb9e3162152861217691',
		author: { name: 'Name2', email: 'Email2@example.com' },
		message: 'Test save commit',
		changes: [] 
	},
	{
		path: 'testLogDir/saveTest.txt',
		id: '0da471f7226f1db0b2fc6307c7f1ec7b4f9c108c',
		author: { name: 'Name', email: 'Email@example.com' },
		message: 'Test create commit',
		changes: [] }
	]

	revs = git.parseLogLines(logText);

	q.ok(revs,'Lines are returned')
	for rev, i in revs
		expected = expectedRevs[i];
		q.equal rev.path, expected.path, "Path #{i} is correct"
		# console.log rev.author
		# console.log expected.author
		q.equal rev.author.name, expected.author.name, "Author name #{i} is correct"
		q.equal rev.author.email, expected.author.email, "Author email #{i} is correct"

		q.equal rev.message, expected.message, "Message #{i} is correct"
		q.ok rev.id, "ID #{i} exists"
		q.ok rev.time, "Time #{i} exists"
)

q.test('create',->
	q.expect(5)

	createPath1 = 'createTest.txt'
	createPath2 = 'space test.txt'
	createPath3 = 'folder/test.txt'


	createText = 'hello world'
	createAuthor = new store.Author('Name','Email@email.com')
	createMessage = 'Test create commit'
	q.stop()

	async.series [

		# createPath1
		(callback) ->
			git.create(createPath1, createText, createAuthor, createMessage, (err,returnedResource) ->
				q.ok(not err?, 'No error on creating file 1')
				if err? then console.log(err)
						
				async.parallel([
					(cb) ->
						git.read(createPath1, null, (err, retrievedResourceText) ->
							q.equal(retrievedResourceText,createText, 'Created file has proper contents')
							if err? then console.log(err)
							cb(err)
						)
					,
					(cb) ->
						git.latest(createPath1, (err, returnedRevision) ->
							q.ok(returnedRevision, 'A revision is returned')
							cb(null)
						)
				],(err) -> callback())
			)

		# createPath2
		(callback) -> 
			git.create(createPath2, createText, createAuthor, createMessage, (err,returnedResource) ->
				q.ok(not err?, 'No error on creating file 2')
				if err? then console.log(err);

				callback()
			)

		# createPath3
		(callback) -> 
			git.create(createPath3, createText, createAuthor, createMessage, (err,returnedResource) ->
				q.ok(not err?, 'No error on creating file 3')
				if err? then console.log(err);

				callback()
			)
	],(err) -> q.start()

)


q.test('save', ->
	q.expect(9)

	createPath = savePath = 'saveTest.txt'
	createText = 'hello world'
	createAuthor = new store.Author('Name','Email@example.com')
	createMessage = 'Test create commit'

	saveText = 'hello new world'
	saveAuthor = new store.Author('Name2','Email2@example.com')
	saveMessage = 'Test save commit'

	q.stop()

	git.create(createPath, createText, createAuthor, createMessage, (err,returnedResource) ->
		q.ok(not err?, 'No error on creating file')
		if err? then return console.log(err)
		
		git.save savePath,saveText,saveAuthor,saveMessage, (err,returnedResource) ->
			async.parallel([
				(cb) ->
					git.read(savePath, null, (err, retrievedResourceText) ->
						q.equal(retrievedResourceText,saveText, 'Created file has proper contents')
						if err? then console.log(err)
						cb(err)
					)
				,
				(cb) ->
					git.latest(savePath, (err, returnedRevision) ->
						q.ok(not err?, 'No error on retrieving revision')
						q.ok(returnedRevision?, 'A revision is returned')
						q.equal(returnedRevision.author.name, saveAuthor.name, 'Author name is correct')
						q.equal(returnedRevision.author.email, saveAuthor.email, 'Author email is correct')
						q.ok(returnedRevision.id?, 'Revision is assigned an ID')
						q.ok(returnedRevision.time?, 'Revision is assigned a date')
						q.equal(returnedRevision.message,saveMessage)

						cb(null)
					)
			],(err) -> q.start())
	)
)

q.test('log', ->
	# q.expect(13)

	createPath = savePath = 'testLogDir/saveTest.txt'
	createText = 'hello world'
	createAuthor = new store.Author('Name','Email@example.com')
	createMessage = 'Test create commit'

	saveText = 'hello new world'
	saveAuthor = new store.Author('Name2','Email2@example.com')
	saveMessage = 'Test save commit'

	createDate = false

	q.stop()

	git.create(createPath, createText, createAuthor, createMessage, (err,returnedResource) ->
		q.ok(not err?, 'No error on creating file')
		if err? then return console.log(err)
		
		# make date 1 second in future to separate creation and save events
		createDate = new Date()
		createDate.setSeconds(createDate.getSeconds() + 1)

		# create function to be executed in 2 seconds
		doSave = () ->
			git.save savePath,saveText,saveAuthor,saveMessage, (err,returnedResource) ->
				q.ok(not err?, 'No error on saving file')

				async.series [
					(cb) -> 
						git.log savePath, (err, results) ->
							q.ok(not err?, 'No error on log')
							if err then cb(err)

							q.ok(results.length == 2, 'Two revisions are returned')

							q.ok(results[0]?.id && results[1]?.id, 'Revisions have IDs')
							q.ok(results[0]?.id != results[1]?.id, 'Revisions have distinct IDs')

							q.ok(results[0]?.time && results[1]?.time, 'Revisions have distinct times')
							q.ok(results[0]?.time > results[1]?.time, 'Latest revision comes first')

							q.equal(results[1].message, createMessage, 'Create message is correct')
							q.equal(results[0].message, saveMessage, 'Save message is correct')

							q.deepEqual(results[1].author, createAuthor, 'Create author is correct')
							q.deepEqual(results[0].author, saveAuthor, 'Save author is correct')

							q.ok(results[0]?.path == results[1]?.path == createPath, 'Path is correct')

							cb(null)	
					(cb) ->
						# test `since`
						git.log savePath, { since: createDate.toString() }, (err, results) ->
							q.ok(not err?, 'Since: No error on log')
							if err? then cb(err)

							q.ok(results.length == 1, 'Since: One revision is returned')
							q.equal(results[0].message, saveMessage, 'Since: Save message is correct')

							cb(null)

					(cb) ->
						# test `until`
						git.log savePath, { until: createDate.toString() }, (err, results) ->
							q.ok(not err?, 'Until: No error on log')
							if err? then cb(err)

							q.ok(results.length == 1, 'Until: One revision is returned')
							q.equal(results[0].message, createMessage, 'Until: Create message is correct')

							cb(null)

				], (err) -> 
					if err then console.log err
					q.start()
		
		setTimeout(doSave, 2000)
	)
)
q.test('list', ->
	q.expect(5)

	dirPath = 'testDir'

	testFile1 = pth.join(dirPath,'test1.txt')
	testFile2 = pth.join(dirPath,'test2.txt')
	testFile3 = pth.join(dirPath,'test3.txt')

	innerDir = pth.join(dirPath,'innerDir')
	testFile4 = pth.join(innerDir,'test4.txt')

	createText = 'hello world'
	createAuthor = new store.Author('Name','Email@example.com')
	createMessage = 'Test create commit'

	q.stop()

	async.series [
		(cb) -> git.create(testFile1, createText, createAuthor, createMessage, cb),
		(cb) -> git.create(testFile2, createText, createAuthor, createMessage, cb),
		(cb) -> git.create(testFile3, createText, createAuthor, createMessage, cb)
		(cb) -> git.create(testFile4, createText, createAuthor, createMessage, cb)

	], (err, results) -> 
		q.ok(not err?, 'No error on creating test files')
		git.list(dirPath, (err, resources) ->
			resources.sort( (a,b) -> a.path > b.path )

			q.equal(resources[1]?.path, testFile1, 'Test file 1 is present')
			q.equal(resources[2]?.path, testFile2, 'Test file 2 is present')
			q.equal(resources[3]?.path, testFile3, 'Test file 3 is present')
			q.equal(resources[0]?.path, innerDir+'/',  'Inner directory is present')

			q.start()
		)
)


q.test('type',->
	q.expect(4)

	dirPath = 'testTypeDir'

	testFile = pth.join(dirPath,'test1.txt')

	createText = 'hello world'
	createAuthor = new store.Author('Name','Email@example.com')
	createMessage = 'Test create commit'

	q.stop()

	git.create(testFile, createText, createAuthor, createMessage, (err, returnedResource) ->
		q.ok(not err?, 'No error on creating test files')

		async.series [
			(cb) -> git.type(testFile, null, (err, type) -> 
				q.equal(type, 'file', 'Type of file is properly detected'); 
				cb(err)),
			(cb) -> git.type(dirPath, null, (err, type) -> 
				q.equal(type, 'folder', 'Type of folder is properly detected'); 
				cb(err)), 
		], (err, results) ->
			q.ok(not err?, 'No error in checking types of files and folder')
			if err then console.log(err)
			q.start()
	)
)


q.test('search', ->
	q.expect(6)

	dirPath = 'testDir'

	testFile1 = pth.join(dirPath,'test1.txt')
	testFile2 = pth.join(dirPath,'test2.txt')
	testFile3 = pth.join(dirPath,'test3.txt')

	createText1 = 'hello world'
	createText2 = 'hello mother'
	createText3 = 'hello father'

	createAuthor = new store.Author('Name','Email@example.com')
	createMessage = 'Test create commit'

	q.stop()

	async.series [
		(cb) -> git.create(testFile1, createText1, createAuthor, createMessage, cb),
		(cb) -> git.create(testFile2, createText2, createAuthor, createMessage, cb),
		(cb) -> git.create(testFile3, createText3, createAuthor, createMessage, cb)
	], (err, results) -> 
		q.ok(not err?, 'No error on creating test files')
		git.search('mother',{},(err, matches) ->
			q.ok(not err?, 'No error on searching for "mother"')
			q.ok(matches.length==1, 'One match')
			q.equal(matches[0][0]?.path,testFile2, 'Match has correct path')
			q.equal(matches[0][1],1, 'Match has correct line number')
			q.equal(matches[0][2],createText2, 'Match has correct text')
			q.start()
		)
)



