var util = require('util'),
	spawn = require('child_process').spawn,
	child_process = require('child_process')

function cmd(command, options, callback) {
	console.log(command,options)
	return exec(command,options,callback)
	// return child_process.exec(command, options, callback)
}

function sanitizeShellString (s) {
	s = s.replace('\\','\\\\');
	s = s.replace('"','\\"');
	s = s.replace("'","\\'");
	return "'" +s+ "'";
}

function cleanPath (p) {
	var p1 = p.replace(/[^\w\- \.\/]/g,'')
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



function exec(command /*, options, callback */) {
	var file, args, options, callback;

	if (typeof arguments[1] === 'function') {
		options = undefined;
		callback = arguments[1];
	} else {
		options = arguments[1];
		callback = arguments[2];
	}

	if (process.platform === 'win32') {
		file = 'cmd.exe';
		args = ['/s', '/c', '"' + command + '"'];
		// Make a shallow copy before patching so we don't clobber the user's
		// options object.
		options = util._extend({}, options);
		options.windowsVerbatimArguments = true;
	} else {
		file = '/bin/sh';
		args = ['-c', command];
	}

	if (options && options.shell)
		file = options.shell;

	return execFile(file, args, options, callback);
};


function execFile(file /* args, options, callback */) {
	var args, callback;
	var options = {
		encoding: 'utf8',
		timeout: 0,
		maxBuffer: 200 * 1024,
		killSignal: 'SIGTERM',
		cwd: null,
		env: null
	};

	// Parse the parameters.

	if (typeof(arguments[arguments.length - 1]) === 'function') {
		callback = arguments[arguments.length - 1];
	}

	if (util.isArray(arguments[1])) {
		args = arguments[1];
		options = util._extend(options, arguments[2]);
	} else {
		args = [];
		options = util._extend(options, arguments[1]);
	}

	var child = spawn(file, args, {
		cwd: options.cwd,
		env: options.env,
		windowsVerbatimArguments: !!options.windowsVerbatimArguments
	});

	var encoding;
	var _stdout;
	var _stderr;
	if (options.encoding !== 'buffer' && Buffer.isEncoding(options.encoding)) {
		encoding = options.encoding;
		_stdout = '';
		_stderr = '';
	} else {
		_stdout = [];
		_stderr = [];
		encoding = null;
	}
	var stdoutLen = 0;
	var stderrLen = 0;
	var killed = false;
	var exited = false;
	var timeoutId;

	var ex;

	function exithandler(code, signal) {
		if (exited) return;
		exited = true;

		if (timeoutId) {
			clearTimeout(timeoutId);
			timeoutId = null;
		}

		if (!callback) return;

		// merge chunks
		var stdout;
		var stderr;
		if (!encoding) {
			stdout = Buffer.concat(_stdout);
			stderr = Buffer.concat(_stderr);
		} else {
			stdout = _stdout;
			stderr = _stderr;
		}

		if (ex) {
			callback(ex, stdout, stderr);
		} else if (code === 0 && signal === null) {
			callback(null, stdout, stderr);
		} else {
			ex = new Error('Command failed: ' + stderr);
			ex.killed = child.killed || killed;
			ex.code = code < 0 ? uv.errname(code) : code;
			ex.signal = signal;
			callback(ex, stdout, stderr);
		}
	}

	function errorhandler(e) {
		ex = e;
		child.stdout.destroy();
		child.stderr.destroy();
		exithandler();
	}

	function kill() {
		child.stdout.destroy();
		child.stderr.destroy();

		killed = true;
		try {
			child.kill(options.killSignal);
		} catch (e) {
			ex = e;
			exithandler();
		}
	}

	if (options.timeout > 0) {
		timeoutId = setTimeout(function() {
			kill();
			timeoutId = null;
		}, options.timeout);
	}

	child.stdout.addListener('data', function(chunk) {
		stdoutLen += chunk.length;

		if (stdoutLen > options.maxBuffer) {
			ex = new Error('stdout maxBuffer exceeded.');
			kill();
		} else {
			if (!encoding)
				_stdout.push(chunk);
			else
				_stdout += chunk;
		}
	});

	child.stderr.addListener('data', function(chunk) {
		stderrLen += chunk.length;

		if (stderrLen > options.maxBuffer) {
			ex = new Error('stderr maxBuffer exceeded.');
			kill();
		} else {
			if (!encoding)
				_stderr.push(chunk);
			else
				_stderr += chunk;
		}
	});

	if (encoding) {
		child.stderr.setEncoding(encoding);
		child.stdout.setEncoding(encoding);
	}

	child.addListener('close', exithandler);
	child.addListener('error', errorhandler);

	return child;
};

module.exports = {
	cmd: cmd,
	command: cmd,

	sanitizeShellString: sanitizeShellString,
	sanitizePath: sanitizePath,
	cleanPath: cleanPath,

}