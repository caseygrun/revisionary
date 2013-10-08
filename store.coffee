
class Resource
	constructor: (@path, @contents=null, @latest=null) ->

	getContents: (store, cb) -> @contents || store.read(this.path,cb)

	getLatest: (store, cb) -> @latest || store.latest(this.path, cb)


class Author 
	constructor: (@name, @email) ->

	toString: ->
		return "#{@name} <#{@email}>"


class Change 
	constructor: (@added, @deleted, @modified) ->


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

module.exports = {
	Store: Store,
	Author: Author, 
	Change: Change,
	Resource: Resource,
	Revision: Revision
}