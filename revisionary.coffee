core = require('./core')
git = require('./git')

core.Store.create = (engine, args...) ->
	cls = engines[engine]
	if cls? then new cls(args...)
	else throw new Error "Unknown engine `#{engine}`"

engines = {
	git: git
}


module.exports = {
	Store: core.Store,
	Author: core.Author, 
	Change: core.Change,
	Resource: core.Resource,
	Revision: core.Revision
	engines: engines
}
