
###*
 * A resource represents a file or directory in the store
###
class Resource
	constructor: (@path, @contents=null, @latest=null) ->

	getContents: (store, cb) -> @contents || store.read(this.path,cb)

	getLatest: (store, cb) -> @latest || store.latest(this.path, cb)

###*
 * Describes the author of a revision
###
class Author 
	###*
	 * @constructor
	 * @param  {String} name
	 * @param  {String} email
	###
	constructor: (@name, @email) ->
		###*
		 * @property {String} name Name of the author
		###
		###*
		 * @property {String} email Email address of the author
		###

	###*
	 * Returns a git-style string representation of the author: `name <email>`
	 * @return {String}
	###
	toString: ->
		return "#{@name} <#{@email}>"


class Change 
	constructor: (@added, @deleted, @modified) ->

###*
 * @class  Revision
 * Represents a single revision in the history of a file
###
class Revision 
	constructor: (@path, @id, @time, @author, @message, @changes) ->

	getContents: (store) ->


class Store
	constructor: (options,callback) ->

	save: (path, contents, author, message, callback) ->

	read: (path, id, callback) ->

	retrieve: (id, callback) -> 

	remove: (path, callback) -> 

	move: (fromPath, toPath) -> 

	list: (directory) -> 

	search: (pattern) -> 

	@create: (engine, args...) ->
		cls = Store.engines[engine]
		if cls? then new cls(args...)
		else throw new Error "Unknown engine `#{engine}`"

	@engines : {
		git: require('./git')
	}

module.exports = {
	Store: Store,
	Author: Author, 
	Change: Change,
	Resource: Resource,
	Revision: Revision
}