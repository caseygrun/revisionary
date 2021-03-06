utils = require('./utils')
store = require('./core')

_ = require('underscore')
async = require('async')
mkdirp = require('mkdirp')
fs = require('fs')
pth = require('path')

###*
 * @class GitStore
 * @extends Store
###
class GitStore extends store.Store
	###*
	 * Constructs a new Git-backed revisionary store
	 * @param  {String} path Path to the repository
	###
	constructor: (@path) ->
		###*
		 * @property {String} path Path to this repository in the file system
		###

	###*
	 * @private
	 * Performs a command in the directory of the repository and buffers the output
	 * @param  {String} command
	 * @param  {Object} options
	 * @param  {Function} callback
	 * @param {Error} [callback.err=null]
	 * @param {String} callback.stdout
	 * @param {String} callback.stderr
	###
	cmd: (str, options={}, callback) ->
		if !callback and _.isFunction(options)
			callback = options; options = {};

		options = _.extend(options, { cwd: this.path }) 
		utils.cmd(str,options, callback)

	###*
	 * @private
	 * Performs a commit
	 * @param  {String} path
	 * @param  {String} message
	 * @param  {store.Author} author
	 * @param  {Function} callback
	 * @param {Error} callback.err
	 * @param {String} callback.stdout
	 * @param {String} callback.stderr
	###
	commit: (path,message,author,cb) ->
		authorString = utils.sanitizeShellString(author.toString());
		this.cmd("git commit --author=#{authorString} -m #{message} -- #{path}", {
			env: {
				GIT_AUTHOR_NAME: author.name,
				GIT_AUTHOR_EMAIL: author.email,
				GIT_COMMITTER_NAME: author.name,
				GIT_COMMITTER_EMAIL: author.email 
			} 
		}, cb) 

	###*
	 * Detects the presence of a repository in the present #path
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param {Error} callback.err Error if one occurs 
	 * @param {Boolean} callback.result true if a repository exists in this location, else false
	###
	detect: (callback) ->
		fs.exists this.path, (exists) =>
			if exists
				this.cmd 'git status',(err, stdout, stderr) -> callback(err, not err?)
			else 
				callback(null, false)
		
	###*
	 * Initializes a repository
	 * @param  {Object} options 
	 * @param  {Function} callback 
	 * @param {Error|null} callback.err An error, if one occurs during initialization, else null
	###
	initialize: (options, callback) ->
		fs.exists this.path, (exists) =>
			if not exists then mkdirp.sync(this.path)
			this.cmd('git init',(err, stdout, stderr) -> callback(err))

	create: (path, contents, author, message, callback) ->
		dirPath = pth.join(this.path, pth.dirname(path))
		#console.log(dirPath)

		mkdirp dirPath, null, (err,made) => 
			if err? then console.log(err); return callback(err)
			@save(path,contents,author,message,callback)

	###*
	 * Saves a resource at the given path. Creates it if it does not exist
	 * @param  {String} path Path to the resource, relative to repository root
	 * @param  {String/Buffer} contents Contents of the resource
	 * @param  {store.Author} author Author of the commit to be recorded
	 * @param  {String} message Message describing the commit
	 * 
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param  {Error} callback.err Error if one occurs during the save
	 * @param  {store.Resource} callback.res Resource created by the #save
	###
	save: (path, contents, author, message, callback) ->
		message = utils.sanitizeShellString(message);
		
		# The path with objectionable characters removed, but still spaces unescaped
		rawPath = utils.cleanPath(path);

		# The path suitable for passing to git (e.g. spaces escaped)
		path = utils.sanitizePath(path);

		async.series([
			# writeFile 
			(cb) => fs.writeFile(pth.join(this.path,rawPath), contents, {}, cb),
			
			(cb) => this.cmd("git add #{path}",cb),

			# git commit 
			(cb) => this.commit(path, message, author, cb)
			
		], (err,stdout,stdin) ->
			if err? then return callback(err)
			return callback(null,new store.Resource(path,contents))
		)

	###*
	 * Reads the {@link store.Resource#contents} of a {@link store.Resource} at the given `path`
	 * @param  {String} path Path to the resource, relative to the repository root
	 * @param  {String} [id=null] 
	 * Identifier of the {@link store.Revision revision} of the resource to load. If `null`, the latest revision
	 * is loaded.
	 * 
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param  {Error} callback.err Error if one occurs during the read
	 * @param {String} contents Contents of the resource
	###
	read: (path, options=null, callback) ->
		if _.isFunction(options) and (not callback?)
			callback = options; options = null 

		objectName = utils.sanitizeShellString(if options?.id? then "#{id}:#{path}" else "HEAD:#{path}")
		this.cmd("git cat-file -p #{objectName}",options,(err,stdout,stderr) -> 
			if err? then return callback(err)
			callback(null,stdout);
		);

	###*
	 * Determines if a given resource exists
	 * @param  {String} path Path to the resource, relative to the repository root
	 * @param {String} [id=null] Optionally an identifier to a revision of this resource
	 * 
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param  {Error} callback.err Error if one occurs during the read
	 * @param {Boolean} callback.exists True if the resource/revision exists
	###
	exists: (path, id=null, callback) ->
		if _.isFunction(id) and (not callback?)
			callback = id; id = null 

		@type path, id, (err, type) -> callback(err, !!type)

	###*
	 * Determines the type of the resource at a given path
	 * @param  {String} path Path to the resource, relative to the repository root
	 * @param {String} [id=null] Optionally an identifier to a revision of this resource
	 * 
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param  {Error} callback.err Error if one occurs during the read
	 * @param {Boolean} callback.type Either `'folder'` or `'file'`, or `null` if the resource does not exist.
	 *	
	###
	type: (path, id=null, callback) ->
		if _.isFunction(id) and (not callback?) 
			callback = id
			id = null

		objectName = utils.sanitizeShellString(if id? then "#{id}:+#{path}" else "HEAD:#{path}")

		this.cmd("git cat-file -t #{objectName}",(err,stdout,stderr) -> 
			if err? then return callback(null, null)

			callback null, switch stdout.trim()
				when "tree" then "folder"
				when "blob" then "file"
		);


	###*
	 * Retrieves the metadata associated with a particular {@link store.Revision revision} of a 
	 * {@link store.Resource resource}.
	 * 
	 * @param  {String} path Path to the resource, relative to the repository root
	 * @param  {String} id Identifier of the {@link store.Revision revision} of the resource to load.
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param  {Error} callback.err Error if one occurs during the read
	 * @param {store.Resource} callback.res Resource object containing retrieved metadata
	###
	retrieve: (path, id, callback) ->
		objectName = utils.sanitizeShellString(if id? then "#{id}:+#{path}" else "HEAD:#{path}")
		this.cmd("git whatchanged -z --pretty='format:#{@logFormat}' --max-count=1 #{id}",(err,stdout,stderr) -> 
			if err? then return callback(err)
			callback(null,@parseLog(path,stdout));
		);		

	###*
	 * Returns the metadata associated with the most recent revision of a resource
	 * @param  {String} path Path to the resource, relative to the repository root
	 * @param  {Function} callback [description]
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param  {Error} callback.err Error if one occurs during the read
	 * @param {store.Resource} callback.res Resource object containing retrieved metadata
	###
	latest: (path, callback) ->
		path = utils.sanitizePath(path)
		this.cmd("git log --pretty='format:#{@logFormat}' --max-count=1 HEAD -- #{path}",(err,stdout,stderr) => 
			if err? then return callback(err)
			callback(null,@commitRevision(path,@parseCommit(stdout)));
		);

	###*
	 * Removes a given object
	 * @param  {String} path Path to the resource
	 * @param  {Function} callback Callback to be executed upon completion
	###
	remove: (path, author, message, callback) -> 
		path = utils.sanitizePath(path);

		authorString = utils.sanitizeShellString(author.toString())
		message = utils.sanitizeShellString(message)

		this.cmd("git rm #{path} && git commit --author=#{authorString} -m #{message} -- #{path}", callback)

	###*
	 * Moves an objets from one location to another
	 * @param  {Strin} fromPath Path to the Resource
	 * @param  {String} toPath Path to the new location of the Resource
	 * @param  {store.Author} author Author of the commit
	 * @param  {String} message Commit message
	 * @param  {Function} callback Callback to be executed upon completion
	###
	move: (fromPath, toPath, author, message, callback) -> 
		fromPath = utils.sanitizePath(fromPath)
		toPath = utils.sanitizePath(toPath)
		authorString = utils.sanitizeShellString(author.toString())
		message = utils.sanitizeShellString(message)

		this.cmd("git mv #{fromPath} #{toPath} && git commit --author=#{authorString} -m #{message} -- #{toPath} #{fromPath}",
			(err,stdout,stderr) -> callback(err));

	###*
	 * Lists all resources in a repository, optionally starting from a given 
	 * directory and recursing downwards. See #list for a non-recursive 
	 * version.
	 * @param  {String} [directory='/']
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param {store.Resource[]} callback.resources List of resources contained in the directory or its subdirectories
	###
	all: (directory, callback) ->
		objectName = if directory isnt '/' then utils.sanitizeShellString("HEAD:"+utils.sanitizePath(directory)) else '"HEAD"'
		this.cmd("git ls-tree --full-tree -z -r #{objectName}", (err, stdout, stderr) =>
			# -> <mode> SP <type> SP <object> TAB <file>

			if err? then return callback(err)

			callback(null,for line in stdout.split('\x00') when line
				[mode,type,id,path] = line.match(@listPattern) 
				if type == 'tree' then path += '/' 
				new store.Resource(pth.join(directory,path))
			)
		)

	###*
	 * Returns a list of resources in a directory. Does not recurse to 
	 * subdirectories; see #all for that behavior.
	 * @param  {String} [directory='/']
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param {store.Resource[]} callback.resources List of resources contained in the directory
	###
	list: (directory,callback) -> 
		objectName = if directory isnt '/' then utils.sanitizeShellString("HEAD:"+utils.sanitizePath(directory)) else '"HEAD"'
		this.cmd("git ls-tree -z #{objectName}", (err, stdout, stderr) =>
			# -> <mode> SP <type> SP <object> TAB <file>

			if err? then return callback(err)

			callback(null,for line in stdout.split('\x00') when line
				[mode,type,id,path] = line.match(@listPattern) 
				if type == 'tree' then path += '/' 
				new store.Resource(pth.join(directory,path))
			)
		)

	###*
	 * Searches the repository for the given pattern
	 * @param  {String} pattern Pattern to search for; can be a regular expression
	 * @param  {Object} [options] Options affecting the search 
	 * @param {Bool} [options.ignoreCase=false] Case insensitive
	 * @param {Bool} [options.wordRegexp=false] Match only at a word boundary
	 * @param {Bool} [options.allMatch=false]
	 * 
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param {Array[]} callback.matches 
	 * List of matches. Each match is an array: `[res, line, matchText]`, where:
	 *     - `res` {store.Resource} is the matching resource
	 *     - `line` {Number} is the line number where the match was found
	 *     - `matchText` {String} is the text of the line where the match was found 
	###
	search: (pattern, options, callback) -> 
		args = [];
		args.push('--ignore-case') if options.ignoreCase
		args.push('--word-regexp') if options.wordRegexp
		args.push('--all-match') if options.allMatch

		pattern = utils.sanitizeShellString(pattern)

		this.cmd("git grep -I -n #{args.join(' ')} -e #{pattern}", (err,stdout,stderr) =>
			if err? 
				if err.code? and err.code == 1 then return callback(null, [])
				else return callback(err)

			callback(err, (for line in stdout.split('\n') when line
				[all,path,line,match] = line.match(@searchPattern) 
				[new store.Resource(path),line,match]
			))
		)
		# -> filename:line:match

	###*
	 * Retrieves a list of revisions associated with the particular resource
	 * @param  {String} path Path to the resource, relative to the repository root
	 * 
	 * @param  {Object} [options=null] Hash of options 
	 * @param {Date} [options.since=null] Select changes after this particular date
	 * @param {Date} [options.until=null] Select changes before this particular date
	 * @param {Number} [options.limit=null] Select only this number of changes
	 * 
	 * @param  {Function} callback Callback to be executed upon completion
	 * @param  {Error} callback.err Error if one occurs during the read
	 * @param {store.Revision[]} callback.revisions Array of revisions
	###
	log: (path, options=null, callback) ->
		if not callback? and _.isFunction(options)
			callback = options; options = {}

		if path == '/' then path = ''
		path = utils.sanitizePath(path)

		args = []
		if options.since then args.push "--since="+utils.sanitizeShellString(options.since)
		if options.until then args.push "--until="+utils.sanitizeShellString(options.until)
		if options.limit then args.push "-n "+utils.sanitizeShellString(options.until)


		# %x01 %H %x00 %ct %x00 %an %x00 %ae %x00 %B %n %x00
		this.cmd("git whatchanged --follow --name-only #{args.join(' ')} --pretty='format:#{@logFormat}' -- #{path}", (err,stdout,stderr) =>
			if err? then return callback(err)
			revs = @parseLogLines(stdout)
			callback(null,revs)
		)

	###*
	 * @private
	 * @param  {String} text Input lines from `git whatchanged`
	 * @return {store.Revision[]} Generated revisions
	###
	parseLogLines: (text) ->
		revs = []
		commit = null

		# generate list of revisions from lines of input
		revs = for line in text.split('\n') when line

			# some lines will specify beginnings of new commits
			if @commitPattern.test(line) 
				commit = @parseCommit(line)
				null

			# others will specify particular files being revised 
			else
				@commitRevision line, commit

		# filter lines which produced no revision
		revs = (s for s in revs when s)
		revs

	###*
	 * Format git should use to output commit messages
	 * @private
	 * @type {String}
	###
	# '%H %x00 %an %x00 %ae %x00 %ct %x00 %B'
	logFormat: '%H%x00%an%x00%ae%x00%ct%x00%B',

	###*
	 * Regular expression to parse commit messages
	 * @private
	 * @type {RegExp}
	###
	commitPattern: ///
		(\w+)\0			# Commit hash
		([\w\s]+)\0		# Author name
		([\w\s\.@]+)\0	# Author email
		(\d+)\0			# Commit timestamp
		(.*)			# Commit message
		///

	###*
	 * Regular expression to parse output of git-ls-tree
	 * @private
	 * @type {RegExp}
	###
	listPattern: ///
		\d{6}\x20       # number
		(blob|tree)\x20 # type
		(\w{40})\t      # hash
		([!@\#\$%\^&\*\(\)\-_\+=\w\.\/\\\x20]+) # filename
		///

	searchPattern: ///
					([!@\#\$%\^&\*\(\)\-_\+=\w\.\/\\\x20]+):	# filename
					(\d+):			    # line 
					(.+)			    # match
					///

	###*
	 * Parses a commit message encoded using the #logFormat
	 * @private
	 * @param  {String} line A line of output from a git-log like function with format {@link #logFormat}
	###
	parseCommit: (line) ->
		match = line.match(@commitPattern)
		if match
			match[4] = new Date(parseInt(match[4])*1000)
			match.slice(1)
		else 
			null

	###*
	 * Generates a revision from a path and a {@link #parseCommit parsed commit statement}
	 * @private
	 * @param  {String} path Path to the relevant resource
	 * @param  {Array} commit Parsed commit string (see #parseCommit)
	 * @return {store.Revision} Revision
	###
	commitRevision: (path, commit) ->
		if commit 
			[id, authorName, authorEmail, time, message] = commit
			new store.Revision(path, id, time, new store.Author(authorName,authorEmail), message, [])

module.exports = GitStore
