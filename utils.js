child_process = require('child_process')

function cmd(command, options, callback) {
	// console.log(command,options)
	return child_process.exec(command,options,callback)
}

function sanitizeShellString (s) {
	s = s.replace('\\','\\\\');
	s = s.replace('"','\\"');
	s = s.replace("'","\\'");
	return "'" +s+ "'";
}

function cleanPath (p) {
	var p1 = p.replace(/[^\w \.\/]/g,'')
	do {
		p = p1
		p1 = p.replace('..','')
		p1 = p1.replace('//','/')

	} while (p != p1)
	return p1
}

function sanitizePath (p) {
	p1 = cleanPath(p)
	p1 = p1.replace(/ /g,"\\ ");
	return p1;
}

module.exports = {
	cmd: cmd,
	command: cmd,

	sanitizeShellString: sanitizeShellString,
	sanitizePath: sanitizePath,
	cleanPath: cleanPath,

}