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
	DEBUG: false,

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
				if(__psiphon.DEBUG) {
					console.log("took too long waiting for IPC reply");
				}
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
					if (__psiphon.DEBUG) {
						console.log("not opening _blank a from " + event.type + " event");
					}
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

		/* setup media links rewriting to go via URL proxy */
		__psiphon.setupMediaObservers();

		/* setup URL proxy change listener */
		__psiphon.listenToUrlProxyPortMessage();
	},

	/**
	 * Takes a relative URL and returns an absolute form of it (based on the current location).
	 * @param {string} url - The relative URL that should be made absolute. If it's already
	 * absolute, it will not be altered.
	 */
	absoluteURL: function (url) {
		if(!__psiphon.helperAnchorElement) {
			__psiphon.helperAnchorElement = document.createElement("a");
		}
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

	// Modifies the src attribute on the element to use the URL proxy, if it
	// hasn't already been modified.
	urlProxyElementSrc: function (elem) {
		var originalSrc = elem.src;

		if (!originalSrc || !originalSrc.length) {
			return;
		}

		// Don't try to proxy data URIs.
		if (originalSrc.indexOf('data:') === 0) {
			return;
		}

		// Make the src attr absolute. We can't URL-proxy relative URLs.
		originalSrc = __psiphon.absoluteURL(originalSrc);

		var urlProxyPrefix = 'http://127.0.0.1:' + __psiphon.urlProxyPort + '/tunneled/';

		if (originalSrc.indexOf(urlProxyPrefix) === 0) {
			// Already proxied with current urlProxyPrefix
			return;
		}

		// Check if the attribute has been previously proxied but URL proxy port has changed
		__psiphon.helperAnchorElement.href = originalSrc;
		if (__psiphon.helperAnchorElement.hostname === '127.0.0.1' && parseInt(__psiphon.helperAnchorElement.port) !== __psiphon.urlProxyPort) {
			// update just the port
			__psiphon.helperAnchorElement.port = __psiphon.urlProxyPort;
			if (__psiphon.DEBUG) {
				console.debug('urlProxyElementSrc: updating previously proxied ' + elem.tagName + ' with new URL proxy port:' + __psiphon.urlProxyPort);
			}
			elem.setAttribute('src', __psiphon.helperAnchorElement.href);
			if(elem.parentElement && ['video', 'audio'].includes(elem.parentElement.tagName.toLowerCase())) {
				// reload the media
				elem.parentElement.load();
			}
			return;
		}

		if (__psiphon.DEBUG) {
			console.debug('urlProxyElementSrc: replacing ' + elem.tagName + ' element src: ' + originalSrc);
		}
		elem.setAttribute('src', urlProxyPrefix + encodeURIComponent(originalSrc));
	},

	// Monitors an element for mutations that might require configuring/reconfiguring
	// the URL proxy setup.
	monitorElement: function (elem) {
		// We'll add a custom property to avoid re-adding the MutationObserver.
		if (elem.__psiphon_monitorElement) {
			return;
		}
		elem.__psiphon_monitorElement = true;

		var mutationObserverConfig = {
			attributes: true,
			attributeFilter: ['src'],
			childList: true,
			characterData: false,
			subtree: true
		};

		var mutationObserver = new MutationObserver(function (mutations) {
			var i, j, mutation, node;

			for (i = 0; i < mutations.length; i++) {
				mutation = mutations[i];

				// If the mutation was a src attribute changes, try to proxy the new value.
				if (mutation.type === 'attributes' && ['video', 'audio', 'source'].includes(mutation.target.tagName.toLowerCase())) {
					if (__psiphon.DEBUG) {
						console.debug('monitorElement::MutationObserver: ' + mutation.target.tagName + ' attr src changed');
					}
					__psiphon.urlProxyElementSrc(mutation.target)
					continue;
				}

				if (mutation.type !== 'childList' || mutation.addedNodes.length === 0) {
					continue;
				}

				// If the mutation was new child elements, configure them for proxying.
				for (j = 0; j < mutation.addedNodes.length; j++) {
					node = mutation.addedNodes[j];

					if (node.nodeType !== Node.ELEMENT_NODE) {
						continue;
					}
					if (node.tagName.toLowerCase() == 'source') {
						// New 'source' node has been added to the element
						// and needs to be proxied and monitored.
						__psiphon.urlProxyElementSrc(node);
						__psiphon.monitorElement(node);
					}
				}
			}
		});

		// Start the mutation observation.
		mutationObserver.observe(elem, mutationObserverConfig);
	},

	// Sets up the given media element to have its media data URL proxied.
	// This will involve changing its src attribute, checking for src changes,
	// and doing the same for any <source> child element.
	urlProxyMediaElement: function (elem) {
		var i;

		// Modify any existing src attribute.
		__psiphon.urlProxyElementSrc(elem);
		// Monitor for future changes.
		__psiphon.monitorElement(elem);

		// If there's a <source> child element, modify and monitor it as well.
		if (elem.children && elem.children.length) {
			for (i = 0; i < elem.children.length; i++) {
				if (elem.children[i].tagName.toLowerCase() === 'source') {
					__psiphon.urlProxyElementSrc(elem.children[i]);
					__psiphon.monitorElement(elem.children[i]);
				}
			}
		}
	},

	// Proxies all current media elements in the document
	urlProxyCurrentMediaElements: function() {
		var i, j;
		var mediaTags = ['video', 'audio'];
		for (i = 0; i < mediaTags.length; i++) {
			var elems = document.getElementsByTagName(mediaTags[i]);
			for (j = 0; j < elems.length; j++) {
				__psiphon.urlProxyMediaElement(elems[j]);
			}
		}
	},

	// Go through all existing media elements and modify+monitor them
	setupMediaObservers: function () {
		__psiphon.urlProxyCurrentMediaElements();

		var mediaTags = ['video', 'audio'];
		// Not all media elements exist in the page at this point, so we'll monitor
		// the body of the page for additions.

		var mutationObserverConfig = {
			attributes: false,
			childList: true,
			characterData: false,
			subtree: true
		};

		// create an observer instance
		var mutationObserver = new MutationObserver(function (mutations) {
			var i, j, k, l, mutation, node;

			for (i = 0; i < mutations.length; i++) {
				var mutation = mutations[i];

				if (mutation.type !== 'childList' || mutation.addedNodes.length === 0) {
					continue;
				}

				for (j = 0; j < mutation.addedNodes.length; j++) {
					node = mutation.addedNodes[j];

					if (node.nodeType !== Node.ELEMENT_NODE) {
						continue;
					}

					// Check if the new node or its children contain media elements
					// and set them for monitoring and proxying.
					if (mediaTags.includes(node.tagName.toLowerCase())) {
						if (__psiphon.DEBUG) {
							console.debug('onLoad::MutationObserver: found new ' + node.tagName);
						}
						__psiphon.urlProxyMediaElement(node)
					} else {
						for (k = 0; k < mediaTags.length; k++) {
							var mediaElements = node.getElementsByTagName(mediaTags[k]);
							for (l = 0; l < mediaElements.length; l++) {
								if (__psiphon.DEBUG) {
									console.debug('onLoad::MutationObserver: found new ' + mediaElements[l].tagName);
								}
								__psiphon.urlProxyMediaElement(mediaElements[l])
							}
						}
					}
				}
			}
		});
		// Start the mutation observer. Note that document.body isn't guaranteed to
		// exist for all pages.
		if (document.body) {
			mutationObserver.observe(document.body, mutationObserverConfig);
		}
	},

	// Listens for URL proxy port change message
	// and updates __psiphon.urlProxyPort with new value.
	listenToUrlProxyPortMessage: function () {
		window.addEventListener('message', function (event) {
			if (event.data.event_id === '__psiphon_urlProxyPort') {
				__psiphon.urlProxyPort = event.data.urlProxyPort;
				__psiphon.urlProxyCurrentMediaElements();
				var iframes = document.getElementsByTagName('iframe');
				for (var i = 0; i < iframes.length; i++) {
					iframes[0].contentWindow.postMessage(event.data, '*');
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
	}
};

(function () {
	"use strict";

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

	// Uncomment to override native console logging
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

	if (document.readyState == "complete" || document.readyState == "interactive") {
		__psiphon.onLoad();
	}
	else {
		document.addEventListener("DOMContentLoaded", __psiphon.onLoad, false);
	}
}());
}
