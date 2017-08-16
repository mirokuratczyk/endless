/*
 * Note: This block of Javascript has been injected via the Psiphon browser and is
 * not a part of this website.
 *
 * Copyright (c) 2017, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 * See LICENSE file for redistribution terms.
 */

/*
 * SECURITY NOTE: All of this JavaScript is accessible by the page, as is the
 * ObjC IPC interface. Everything available via IPC must be **bulletproof**.
 */

if (typeof __psiphon == "undefined") {
var __psiphon = {
	// Override if you want to see console messages coming from this script
	TRACE: false,

	// Override if you want console messages to be sent back to the Obj C via IPC
	USE_IPC_CONSOLE: false,

	/**
	 * The time (in milliseconds) that we will wait for an ObjC call to complete.
	 */
	ipcTimeoutMS: 2000,

	/**
	 * Make an asynchronous IPC call to the ObjC code.
	 * See WebViewTab.m for handling code.
	 * @param {string} url - "URL" indicating the IPC call to make. Must not include the scheme.
	 */
	ipc: function(url) {
		// Create an invisible iframe with a src of our special `endlessipc://` URL.
		var iframe = document.createElement("iframe");
		iframe.setAttribute("src", "endlessipc://" + url);
		iframe.setAttribute("height", "1px");
		iframe.setAttribute("width", "1px");

		// Add and remove the iframe from the DOM. This is sufficient to trigger the request.
		document.documentElement.appendChild(iframe);
		iframe.parentNode.removeChild(iframe);
		iframe = null;
	},

	/**
	 * Gets set by ObjC code to a non-null value when an IPC call is complete.
	 */
	ipcDone: null,

	/**
	 * Make an IPC call and wait for a response (or timeout) from the ObjC code.
	 * This function gives no indication whether the IPC call was successful or timed out.
	 * @param {string} url - "URL" indicating the IPC call to make. Must not include the scheme.
	 */
	ipcAndWaitForReply: function(url) {
		// Clear the previous "done" status.
		this.ipcDone = null;

		var start = (new Date()).getTime();

		// Make the async IPC call.
		this.ipc(url);
		// `this.ipcDone` will get set to non-null from ObjC in `webView:callbackWith`.

		while (this.ipcDone == null) {
			if ((new Date()).getTime() - start > this.ipcTimeoutMS) {
				__psiphon.log("took too long waiting for IPC reply");
				break;
			}
		}

		return;
	},

	/**
	 * Links (`<a>` tags) with `target="_blank"` should open in new tabs. This requires help from
	 * ObjC code via a `window.open()` IPC call.
	 * This should get called once when the page is loaded.
	 */
	hookIntoBlankAs: function() {
		// Don't hook into _blank A's if there is no body, such as on t.co pages with just a <head>.
		if (!document.body)
			return;

		document.body.addEventListener("click", function(event) {
			if (event.target.tagName == "A" && event.target.target == "_blank") {
				if (event.type == "click") {
					// A link with target=_blank was clicked. Intercept it.
					event.preventDefault();

					// This window.open call will result in IPC to ObjC.
					// Our `window.open()` call always returns null, so we can't
					// check for success.
					window.open(event.target.href);

					return false;
				}
				else {
					__psiphon.log("not opening _blank a from " + event.type + " event");
				}
			}
		}, false);
	},

	/**
	 * Determine what elements are at the given coordinates.
	 * Returns an array of objects with info about the elements, starting from the deepest child up
	 * to its parent. (But only for some element types.)
	 * NOTE: This function is not called from this file -- it is used by ObjC in `WebViewTab.m::-elementsAtLocationFromGestureRecognizer`.
	 */
	elementsAtPoint: function(x, y) {
		var tags = [];
		// Do nothing if run in a frame
		// TODO: make this run properly in a frame
		if (__psiphon.isInIframe()) {
			return tags;
		}
		var e = document.elementFromPoint(x,y);
		while (e) {
			if (e.tagName) {
				var name = e.tagName.toLowerCase();
				if (name == "a")
					tags.push({ "a": { "href" : e.href, "title" : e.title } });
				else if (name == "img")
					tags.push({ "img": { "src" : e.src, "title" : e.title, "alt" : e.alt } });
			}
			e = e.parentNode;
		}
		return tags;
	},

	runFinalPageReporting: function() {
		/**
		 * Start a timer when page is loaded and report back to the browser after a delay via IPC.
		 * This is used to notify browser that the page has done loading(including redirects).
		 * A list of all redirect URLs(if any) is passed then to the observer delegate
		 * of this tab in the ObjC.
		 */
		setTimeout(function() {
				// If this fires, then the page has been loaded for 1 second.
				// If the timer was created but this doesn't fire, it means this page
				// went away before 1 second elapsed.
				var ipcAction = "pagefinal";
				__psiphon.ipc(ipcAction);
				}, 3000);
	},

	/**
	 * Run-once initialization code.
	 * Must be called when the document DOM is ready.
	 */
	onLoad: function() {
		/* supress default long-press menu */
		if (document && document.body)
			document.body.style.webkitTouchCallout = "none";

		__psiphon.hookIntoBlankAs();

		/* start final page reporting */
		if (!__psiphon.isInIframe) {
			__psiphon.runFinalPageReporting();
		}

		// TODO-DISABLE-JAVASCRIPT: comment out until fixed
		/* ask obj C if js is disabled and noscript tags should be removed */
		//__psiphon.ipcAndWaitForReply("noscript");

		// URL proxify all current media elements
		__psiphon.urlProxyCurrentMediaElements(document);

		/* setup URL proxy change listener */
		__psiphon.listenToUrlProxyPortMessage();
	},

	/**
	 * Takes a relative URL and returns an absolute form of it (based on the current location).
	 * @param {string} url - The relative URL that should be made absolute. If it's already
	 * absolute, it will not be altered.
	 */
	absoluteURL: function (url) {
		__psiphon.helperAnchorElement.href = url; /* browser will make this absolute for us */
		return __psiphon.helperAnchorElement.href;
	},
	// TODO-DISABLE-JAVASCRIPT: comment out until fixed
	/**
	 * Removes <noscript> tags from DOM.
	 * Called from Obj C when javascript is disabled
	 * we need to remove <noscript> tags because we do not actually
	 * disable js in the browser but rather restrict it with CSP
	 */
	 /*
	removeNoscript: function() {
		var noscript = document.getElementsByTagName('noscript');
		for (var i = 0; i < noscript.length; i++) {
			noscript[i].outerHTML = noscript[i].childNodes[0].nodeValue;
		}
	}
	*/

	isInIframe: function () {
		try {
			return window.self !== window.top;
		} catch (e) {
			return true;
		}
	},

	// Media links rewriting related functions below:

	// Hooks into DOM mutation functions of an element
	// created with document.createElement(...) and
	// patches element's src' attribute setter
	patchCreateElement: function (doc) {
		var originalCreateElement = doc.createElement;
		doc.createElement = function () {
			var element = originalCreateElement.apply(this, arguments);
			if (element instanceof HTMLMediaElement) {
				__psiphon.debug('createElement:' + element.tagName);

				// patch DOM mutation functions:
				var props = ['appendChild', 'replaceChild', 'insertBefore'];

				var getPropertyDescriptor = function (obj, prop) {
					var desc;
					try {
						desc = Object.getOwnPropertyDescriptor(obj, prop);
					} catch (e) {
						__psiphon.warn('Can not get property ' + prop + ' of ' + element.tagName + ': ' + e.message);
						return desc;
					}
					if (typeof desc === 'undefined') {
						try {
							var objProto = Object.getPrototypeOf(obj);
						} catch (e) { }
						if (objProto)
							return getPropertyDescriptor(objProto, prop);
					}
					return desc;
				}

				for (var i = 0; i < props.length; i++) {
					(function (el) {
						var prop = props[i];
						var desc = getPropertyDescriptor(el, prop);
						if (desc) {
							if (desc.configurable) {
								if (desc.value) {
									if (typeof desc.value === 'function') {
										var originalValue = desc.value;
										desc.value = function () {
											__psiphon.debug(prop + ': ' + arguments[0]);
											__psiphon.urlProxyElementSrc.apply(this, arguments);
											return originalValue.apply(this, arguments);
										};
									} else {
										__psiphon.warn('Can not patch ' + prop + ': not a function');
									}
								} else {
									__psiphon.warn('Can not patch ' + prop + ': no such property value');
								}
								__psiphon.debug('Patching ' + prop);
								Object.defineProperty(el, prop, desc);
							} else {
								__psiphon.warn('Can not patch ' + prop + ': not configurable');
							}
						}
					})(element);
				}

				// patch src property
				try {
					__psiphon.patchElementSrc(element);
				} catch (e) {
					__psiphon.log(e);
				}
			} else if (element instanceof HTMLIFrameElement) {
				element.addEventListener('load', function (event) {
					var el = event.target;
					var original;
					if (!el.src || el.src.length === 0) {
						__psiphon.patchCreateElement(el.contentDocument);
						try {
							original = el.contentDocument.write;
						} catch (e) { }
					}
					if (original) {
						el.contentDocument.write = function () {
							__psiphon.debug('Will IFRAME contentDocument.write: ' + arguments[0]);
							var ret = original.apply(this, arguments);
							__psiphon.urlProxyCurrentMediaElements(el.contentDocument);
							return ret;
						};
					}
				});
			} else {
				// TODO: patch innerHTML and insertAdjacentHTML.
			}
			return element;
		};
	},

	// URL proxifies element's src attribute and
	// modifies 'src' property setter so all
	// future mutations of the property will be
	// URL proxified.
	urlProxyElementSrc: function (element) {
		if(!element || typeof element.src === 'undefined') {
			return;
		}
		if (typeof element.__psiphon_setAttribute === 'undefined') {
			try {
				__psiphon.patchElementSrc(element);
				// Reload src so it gets proxied.
				if (element.src) {
					element.src = element.src;
				}
			} catch (e) {
				// Patching failed, just proxify current value.
				__psiphon.log(e);
				if (element.src) {
					element.src = __psiphon.proxifyURL(element.src);
				}
			}
		} else {
			// Just reload the element
			if (element.src) {
				element.src = element.src;
			}
		}
	},

	// Modify element's src property and override setAttribute('src')
	patchElementSrc: function (element) {
		if (typeof element.__psiphon_setAttribute === 'undefined') {
			try {
				Object.defineProperty(element, 'src', {
					get: function () {
						return this.getAttribute('src');
					},
					set: function (val) {
						this.setAttribute('src', val);
					}
				});
				// Store original setAttribute of the element
				element.__psiphon_setAttribute = element.setAttribute;
				element.setAttribute = function () {
					if (arguments.length > 1) {
						if (arguments[0].toLowerCase() === 'src' && arguments[1] && arguments[1].length > 0) {
							var proxiedVal = __psiphon.proxifyURL(arguments[1]);
							arguments[1] = proxiedVal;
							__psiphon.debug("Modifying " + element.tagName + ".src with " + proxiedVal);
						}
					}
					return this.__psiphon_setAttribute.apply(this, arguments);
				};
			} catch (e) {
				throw "Could not patch " + element.tagName + " error:" + e.message;
			}
		}
	},

	proxifyURL: function (url) {
		if (!url || !url.length) {
			return "";
		}

		// Don't try to proxy data or blob URIs.
		if (url.indexOf('data:') === 0 || url.indexOf('blob:') === 0 ) {
			return url;
		}

		// Make the src attr absolute. We can't URL-proxy relative URLs.
		url = __psiphon.absoluteURL(url);

		var urlProxyPrefix = 'http://127.0.0.1:' + __psiphon.urlProxyPort + '/tunneled-rewrite/';

		if (url.indexOf(urlProxyPrefix) === 0) {
			// Already proxied with current urlProxyPrefix
			return url;
		}

		// Check if the attribute has been previously proxied but URL proxy port has changed
		__psiphon.helperAnchorElement.href = url;
		if (__psiphon.helperAnchorElement.hostname === '127.0.0.1' && parseInt(__psiphon.helperAnchorElement.port) !== __psiphon.urlProxyPort) {
			// update just the port and return
			__psiphon.helperAnchorElement.port = __psiphon.urlProxyPort;
			__psiphon.debug('proxifyURL: updating previously proxied ' + elem.tagName + ' with new URL proxy port:' + __psiphon.urlProxyPort);
			return __psiphon.helperAnchorElement.href;
		}
		return urlProxyPrefix + encodeURIComponent(url) + '?m3u8=true';
	},

	// Proxifies media data URL of the element.
	// This will involve changing its and any
	// <source> child element src attribute,
	urlProxyMediaElement: function (element) {
		// Modify any existing src attribute.
		__psiphon.urlProxyElementSrc(element);

		// If there's a <source> child element, modify and monitor it as well.
		if (element.children && element.children.length) {
			for (var i = 0; i < element.children.length; i++) {
				var child = element.children[i];
				__psiphon.urlProxyElementSrc(child);
				if (child.parentElement && child.parentElement instanceof HTMLMediaElement) {
					// reload the media
					child.parentElement.load();
				}
			}
		}
	},

	// Proxifies all current media elements in the document
	// We call this function when DOM loads or URL proxy port changes
	// in order to apply the change to all current media DOM nodes
	urlProxyCurrentMediaElements: function(doc) {
		var i, j;
		var mediaTags = ['video', 'audio'];
		for (i = 0; i < mediaTags.length; i++) {
			var elems = doc.getElementsByTagName(mediaTags[i]);
			for (j = 0; j < elems.length; j++) {
				__psiphon.urlProxyMediaElement(elems[j]);
			}
		}
	},

	// Listens for URL proxy port change message, 
	// updates __psiphon.urlProxyPort with new value
	// and applies the change to all currentl media elements
	listenToUrlProxyPortMessage: function () {
		window.addEventListener('message', function (event) {
			if (event.data.event_id === '__psiphon_urlProxyPort') {
				__psiphon.urlProxyPort = event.data.urlProxyPort;
				__psiphon.urlProxyCurrentMediaElements(document);
				var iframes = document.getElementsByTagName('iframe');
				for (var i = 0; i < iframes.length; i++) {
					iframes[i].contentWindow.postMessage(event.data, '*');
				}
			}
		}, false);
	},

	// Messages all URL proxy port listeners
	// with the new proxy port.
	// NOTE: This function is called from Obj C on top window only.
	messageUrlProxyPort:function (port) {
		var message = {
			event_id: '__psiphon_urlProxyPort',
			urlProxyPort: port
		}
		// message top window
		window.postMessage(message, '*');
	},
};

(function () {
	"use strict";

	__psiphon.helperAnchorElement = document.createElement("a");

	// Patch document.createElement early
	__psiphon.patchCreateElement(document);

	// Log global errors
	window.onerror = function(msg, url, line) {
		console.error("[on " + url + ":" + line + "] " + msg);
	}

	// Override `window.open()` so that we can use IPC to ObjC in order to open a new tab.
	// More info about `window.open` here, although there's a lot not implemented here:
	// https://developer.mozilla.org/en-US/docs/Web/API/Window/open
	window.open = function (url, name, specs, replace) {
		var ipcURL = "endlessipc://window.open/?" + encodeURIComponent(__psiphon.absoluteURL(url));

		/*
		 * Fake a mouse event clicking on a link, so that our webview sees the
		 * navigation type as a mouse event.  This prevents popup spam since
		 * dispatchEvent() won't do anything if we're not in a mouse event
		 * already.
		 */
		var l = document.createElement("a");
		l.setAttribute("href", ipcURL);
		l.setAttribute("target", "_blank");
		var e = document.createEvent("MouseEvents");
		e.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false,
			false, false, false, 0, null);
		l.dispatchEvent(e);

		window.event.preventDefault();
		window.event.stopImmediatePropagation();

		// We never supply a window handle back to the caller. This is going to
		// cause problems with some web-apps, but there are too many security
		// issues otherwise.
		return null;
	};

	// Override `window.close()` so that we can use IPC to ObjC to request that this tab be closed.
	window.close = function () {
		__psiphon.ipcAndWaitForReply("window.close");
	};

	if(__psiphon.USE_IPC_CONSOLE) {
		// Override `console.log()` (etc.) in order to use IPC to send log info to ObjC.
		console._log = function(urg, args) {
			if (args.length == 1)
				args = args[0];
			__psiphon.ipc("console.log/" + urg + "?" + encodeURIComponent(JSON.stringify(args)));
		};
		console.log = function() { console._log("log", arguments); };
		console.debug = function() { console._log("debug", arguments); };
		console.info = function() { console._log("info", arguments); };
		console.warn = function() { console._log("warn", arguments); };
		console.error = function() { console._log("error", arguments); };
	}

	// Blackhole log messages if __psiphon.TRACE is false
	__psiphon.log = __psiphon.TRACE ? console.log : function () { };
	__psiphon.debug = __psiphon.TRACE ? console.debug : function () { };
	__psiphon.info = __psiphon.TRACE ? console.info : function () { };
	__psiphon.warn = __psiphon.TRACE ? console.warn : function () { };
	__psiphon.error = __psiphon.TRACE ? console.error : function () { };

	if (document.readyState == "complete" || document.readyState == "interactive") {
		__psiphon.onLoad();
	}
	else {
		document.addEventListener("DOMContentLoaded", __psiphon.onLoad, false);
	}
}());
}
