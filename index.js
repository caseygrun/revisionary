st = require('./store');
git = require('./git');

module.exports = {
	Author: st.Author,
	Resource: st.Resource,
	Change: st.Change,
	Revision: st.Revision,

	Store: st.Store,
	GitStore: git.GitStore,
};