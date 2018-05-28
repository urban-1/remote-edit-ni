/*
 * TODO:
 *   DS102: Remove unnecessary code created because of implicit returns
 *   DS206: Consider reworking classes to avoid initClass
 *   DS207: Consider shorter variations of null checks
 */
let Editor, RemoteEditEditor;
const path = require('path');

let resourcePath = atom.config.resourcePath;
if (!resourcePath) {
	resourcePath = atom.getLoadSettings().resourcePath;
}

try {
	Editor = require(path.resolve(resourcePath, 'src', 'editor'));
} catch (e) {
}
// Catch error
const TextEditor = Editor != null ? Editor : require(path.resolve(resourcePath, 'src', 'text-editor'));

// Defer requiring
let Host = null;
let FtpHost = null;
let SftpHost = null;
let LocalFile = null;
let async = null;
let Dialog = null;
let _ = null;

const SERIALIZATION_VERSION = 1

module.exports =
	(RemoteEditEditor = (function() {
		RemoteEditEditor = class RemoteEditEditor extends TextEditor {
			static initClass() {
				atom.deserializers.add(this);
			}

			constructor(params) {
				if (params == null) {
					params = {};
				}

				super(params);

				// Store our original parameters. These are used later on to
				// initialize a cloned RemoteEditEditor in `copy()`
				this.remoteEditParams = params;

				if (params.host) {
					this.host = params.host;
				} else if (params.reHost) {
					Host = require('../model/host');
					FtpHost = require('../model/ftp-host');
					SftpHost = require('../model/sftp-host');
					this.host = Host.deserialize(params.reHost);
				}  else {
					throw "No host in RemoteEditEditor constructor";
				}
				if (params.localFile) {
					this.localFile = params.localFile;
				} else if (params.reLocalFile) {
					LocalFile = require('../model/local-file');
					this.localFile = LocalFile.deserialize(params.reLocalFile);
				} else {
					throw "No localFile in RemoteEditEditor constructor";
				}

				// This is here for consistency since sometimes the localFile.host
				// is not set. Prefer using this.host instead
				if (!this.localFile.host && params.host) {
					this.localFile.host = params.host
				}
			}

			copy() {
				return new RemoteEditEditor(this.remoteEditParams)
			}

			destroy () {
				// Call parent to remove the view
				TextEditor.prototype.destroy.call(this)
				// Now do our clean-up
				if (this.host)
					this.host.close()
			}

			getIconName() {
				return "globe";
			}

			getTitle() {
				let sessionPath;
				if (this.localFile != null) {
					return this.localFile.name;
				} else if ((sessionPath = this.getPath())) {
					return path.basename(sessionPath);
				} else {
					return "undefined";
				}
			}

			getLongTitle() {
				let directory, i, relativePath;
				if (Host == null) {
					Host = require('./host');
				}
				if (FtpHost == null) {
					FtpHost = require('./ftp-host');
				}
				if (SftpHost == null) {
					SftpHost = require('./sftp-host');
				}

				if (i = this.localFile.remoteFile.path.indexOf(this.host.directory) > -1) {
					relativePath = this.localFile.remoteFile.path.slice((i + this.host.directory.length));
				}

				const fileName = this.getTitle();
				if (this.host instanceof SftpHost && (this.host != null) && (this.localFile != null)) {
					directory = (relativePath != null) ? relativePath : `sftp://${this.host.username}@${this.host.hostname}:${this.host.port}${this.localFile.remoteFile.path}`;
				} else if (this.host instanceof FtpHost && (this.host != null) && (this.localFile != null)) {
					directory = (relativePath != null) ? relativePath : `ftp://${this.host.username}@${this.host.hostname}:${this.host.port}${this.localFile.remoteFile.path}`;
				} else {
					directory = atom.project.relativize(path.dirname(sessionPath));
					directory = directory.length > 0 ? directory : path.basename(path.dirname(sessionPath));
				}

				return `${fileName} - ${directory}`;
			}

			onDidSaved(callback) {
				return this.emitter.on('did-saved', callback);
			}

			save() {
				var self = this
				// I think, here we need a new promise, since the buffer.save()
				// one will most probably resolve... while the inner one is
				// prone to failure
				return new Promise(function(resolve, reject){
					self.buffer.save().then(function(result) {
						self.initiateUpload().then(
							function() {
								self.emitter.emit('saved');
								if (atom.config.get('remote-edit-ni.uploadOptions.closeOnUpload'))
									self.host.close();
								resolve()
							},
							function(err) {
								self.buffer.append("\n")
								reject(err)
							}
						)
					})
				})

			}

			saveAs(filePath) {
				this.buffer.saveAs(filePath);
				this.localFile.path = filePath;
				this.emitter.emit('saved');
				return this.initiateUpload();
			}

			initiateUpload() {
				if (atom.config.get('remote-edit-ni.uploadOptions.uploadOnSave')) {
					return this.upload();
				} else {
					if (Dialog == null) {
						Dialog = require('../view/dialog');
					}
					const chosen = atom.confirm({
						message: "File has been saved. Do you want to upload changes to remote host?",
						detailedMessage: "The changes exists on disk and can be uploaded later.",
						buttons: ["Upload", "Cancel"]
					});
					switch (chosen) {
						case 0:
							return this.upload();
						case 1:
							return;
					}
				}
			}

			upload(connectionOptions) {
				var self = this
				return new Promise(function(resolve, reject) {

					if (connectionOptions == null) {
						connectionOptions = {};
					}
					if (async == null) {
						async = require('async');
					}
					if (_ == null) {
						_ = require('underscore-plus');
					}

					if ((self.localFile == null) || (self.host == null)) {
						reject()
						return console.error('LocalFile and host not defined. Cannot upload file!');
					}

					async.waterfall([
						callback => {
							if (!self.host.usePassword || (connectionOptions.password == null)) {
								return callback(null);
							}

							if (!!self.host.password) {
								return callback(null);
							}

							return async.waterfall([
								function(callback) {
									if (Dialog == null) {
										Dialog = require('../view/dialog');
									}
									const passwordDialog = new Dialog({
										prompt: "Enter password", type: 'password'
									});
									return passwordDialog.toggle(callback);
								}
							], (err, result) => {
								connectionOptions = _.extend({
									password: result
								}, connectionOptions);
								return callback(null);
							});

						},
						callback => {
							if (!self.host.isConnected()) {
								return self.host.connect(callback, connectionOptions);
							} else {
								return callback(null);
							}
						},
						callback => {
							// Resolve only after we write the file on the remote
							// and only if the write was successfull
							self.host.writeFile(self.localFile, (err) => {
								if (!err) resolve()
								callback(err)
							});
						}
					], err => {
						if ((err != null) && self.host.usePassword) {
							return async.waterfall([
								function(callback) {
									if (Dialog == null) {
										Dialog = require('../view/dialog');
									}
									const passwordDialog = new Dialog({
										prompt: "Enter password"
									});
									return passwordDialog.toggle(callback);
								}
							], (err, result) => {
								return self.upload({
									password: result
								});
							});

						} else if (err != null) {
							console.log("Rejecting!")
							reject(err)
						}
					});
				})
			}

			serialize () {
				return {
					deserializer: 'RemoteEditEditor',
					version: SERIALIZATION_VERSION,

					displayLayerId: this.displayLayer.id,
					selectionsMarkerLayerId: this.selectionsMarkerLayer.id,

					initialScrollTopRow: this.getScrollTopRow(),
					initialScrollLeftColumn: this.getScrollLeftColumn(),

					tabLength: this.displayLayer.tabLength,
					atomicSoftTabs: this.displayLayer.atomicSoftTabs,
					softWrapHangingIndentLength: this.displayLayer.softWrapHangingIndent,

					id: this.id,
					bufferId: this.buffer.id,
					softTabs: this.softTabs,
					softWrapped: this.softWrapped,
					softWrapAtPreferredLineLength: this.softWrapAtPreferredLineLength,
					preferredLineLength: this.preferredLineLength,
					mini: this.mini,
					readOnly: this.readOnly,
					editorWidthInChars: this.editorWidthInChars,
					width: this.width,
					maxScreenLineLength: this.maxScreenLineLength,
					registered: this.registered,
					invisibles: this.invisibles,
					showInvisibles: this.showInvisibles,
					showIndentGuide: this.showIndentGuide,
					autoHeight: this.autoHeight,
					autoWidth: this.autoWidth,

					reLocalFile: this.localFile != null ? this.localFile.serialize() : undefined,
					reHost: this.host != null ? this.host.serialize() : undefined
				}
			}

			static deserialize (state, atomEnvironment) {

				if (state.version !== SERIALIZATION_VERSION) return null

				let bufferId = state.tokenizedBuffer
					? state.tokenizedBuffer.bufferId
					: state.bufferId

				try {
					state.buffer = atomEnvironment.project.bufferForIdSync(bufferId)
					if (!state.buffer) return null
				} catch (error) {
					if (error.syscall === 'read') {
						return // Error reading the file, don't deserialize an editor for it
					} else {
						throw error
					}
				}

				state.assert = atomEnvironment.assert.bind(atomEnvironment)
				const editor = new RemoteEditEditor(state)
				if (state.registered) {
					const disposable = atomEnvironment.textEditors.add(editor)
					editor.onDidDestroy(() => {
						disposable.dispose()
					})
				}
				return editor
			}
		};
		RemoteEditEditor.initClass();
		return RemoteEditEditor;
	})());
