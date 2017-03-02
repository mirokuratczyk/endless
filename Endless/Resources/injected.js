/*
 * Note: This block of Javascript has been injected via the Endless browser and is
 * not a part of this website.
 *
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 * See LICENSE file for redistribution terms.
 */

/*
 * SECURITY NOTE: All of this JavaScript is accessible by the page, as is the
 * ObjC IPC interface. Everything available via IPC must be **bulletproof**.
 */

if (typeof __endless == "undefined") {
var __endless = {
	/**
	 * Keeps track of all child windows/tabs opened via `window.open()`.
	 * Maps unique IDs to FakeWindow objects.
	 */
	openedTabs: {},

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
				console.log("took too long waiting for IPC reply");
				break;
			}
		}

		return;
	},

	/**
	 * Generate a random ID to be used as a FakeWindow identifier.
	 * @returns {string}
	 */
	randID: function() {
		var a = new Uint32Array(5);
		window.crypto.getRandomValues(a);
		return a.join("-");
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

		document.body.addEventListener("click", function() {
			if (event.target.tagName == "A" && event.target.target == "_blank") {
				if (event.type == "click") {
					// A link with target=_blank was clicked. Intercept it.
					event.preventDefault();

					// This window.open call will result in IPC to ObjC, returning a FakeWindow if
					// successful and null if unsuccessful.
					if (window.open(event.target.href) == null)
					{
						// Tab open attempt was unnsuccessful. Open the link in the current tab.
						window.location = event.target.href;
					}
					return false;
				}
				else {
					console.log("not opening _blank a from " + event.type + " event");
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

	/**
	 * Run-once initialization code.
	 * Must be called when the document DOM is ready.
	 */
	onLoad: function() {
		/* supress default long-press menu */
		if (document && document.body)
			document.body.style.webkitTouchCallout = "none";

		__endless.hookIntoBlankAs();
	},

	/**
	 * Takes a relative URL and returns an absolute form of it (based on the current location).
	 * @param {string} url - The relative URL that should be made absolute. If it's already
	 * absolute, it will not be altered.
	 */
	absoluteURL: function (url) {
		var a = document.createElement("a");
		a.href = url; /* browser will make this absolute for us */
		return a.href;
	},

	/**
	 * FakeWindow
	 * `window.open()` returns a window object that can be used to get info about the new window
	 * and control its location. In order to support that function, we'll need to maintain a
	 * communication channel with the new windows (in a new tab) via ObjC.
	 * This class is used to provide access to child windows/tabs via ObjC.
	 * @param {string} id - A unique identifier for the object. (Will be randomly generated.)
	 */
	FakeWindow: function(id) {
		// Unique ID for this object.
		this.id = id;

		// Indicates if the window/tab was successfully opened. Will be set to true by Objc code
		// on success.
		this.opened = false;

		// The FakeLocation wrapper for this window.
		this._location = null;

		// The storage variable for the `window.name` property.
		this._name = null;
	},

	/**
	 * FakeLocation is used by FakeWindow to track the child tab's URL info.
	 * @param {Location} [real] - The (window.)location object that this will be wrapping or
	 * replacing. NOTE: This argument is only ever used from ObjC IPC code.
	 */
	FakeLocation: function (real) {
		// The ID of the FakeWindow that owns this object.
		this.id = null;

		// Keep references to the original object that we're wrapping.
		for (var prop in real) {
			this["_" + prop] = real[prop];
		}

		this.toString = function () {
			return this._href;
		};
	},
};

(function () {
	"use strict";

	/*
	 * FakeWindow class initialization
	 */

	 // Implement some common `window` properties and functions. We need to make IPC calls to ObjC
	 // in order to access other tabs.
	__endless.FakeWindow.prototype = {
		constructor: __endless.FakeWindow,

		set location(loc) {
			this._location = new __endless.FakeLocation();
			__endless.ipcAndWaitForReply("fakeWindow.setLocation/" + this.id + "?" + encodeURIComponent(loc));
			this._location.id = this.id;
		},
		set name(n) {
			this._name = null;
			__endless.ipcAndWaitForReply("fakeWindow.setName/" + this.id + "?" + encodeURIComponent(n));
		},
		set opener(o) {
		},

		// getters: Disallowed to minimize security exposure. Note that this might impact the
		// functioning of some web pages/services.
		get location() {
			throw "security error trying to access window.location of other window";
		},
		get name() {
			throw "security error trying to access window.name of other window";
		},
		get title() {
			throw "security error trying to access window.title of other window";
		},
		get opener() {
		},

		close: function() {
			__endless.ipcAndWaitForReply("fakeWindow.close/" + this.id);
		},

		toString: function() {
			return "[object FakeWindow]";
		},
	};

	/*
	 * FakeLocation class initialization
	 */

	__endless.FakeLocation.prototype = {
		constructor: __endless.FakeLocation,
	};

	// Implement typical `window.location` properties.
	["hash", "hostname", "href", "pathname", "port", "protocol", "search", "username", "password", "origin"].forEach(function (property) {
		Object.defineProperty(__endless.FakeLocation.prototype, property, {
			// setter: Make an IPC call through ObjC to the target tab.
			set: function (v) {
				eval("this._" + property + " = null;");
				__endless.ipcAndWaitForReply("fakeWindow.setLocationParam/" + this.id + "/" + property + "?" + encodeURIComponent(v));
			},
			// getter: Disallowed. In a real browser, the opener can access window location
			// properties if they share a domain, but we're not allowing to help ensure there's no
			// security issue. Note that this might impact the functioning of some web
			// pages/services.
			get: function () {
				throw "security error trying to access location." + property + " of other window";
			},
		});
	});

	// Log global errors
	window.onerror = function(msg, url, line) {
		console.error("[on " + url + ":" + line + "] " + msg);
	}

	// Override `window.open()` so that we can use IPC to ObjC in order to open a new tab.
	// More info about `window.open` here, although there's a lot ignore:
	// https://developer.mozilla.org/en-US/docs/Web/API/Window/open
	window.open = function (url, name, specs, replace) {
		// This is the ID that will be used to later access the new tab via IPC.
		var id = __endless.randID();

		__endless.openedTabs[id] = new __endless.FakeWindow(id);

		/*
		 * Fake a mouse event clicking on a link, so that our webview sees the
		 * navigation type as a mouse event.  This prevents popup spam since
		 * dispatchEvent() won't do anything if we're not in a mouse event
		 * already.
		 */
		var l = document.createElement("a");
		l.setAttribute("href", "endlessipc://window.open/" + id);
		l.setAttribute("target", "_blank");
		var e = document.createEvent("MouseEvents");
		e.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false,
			false, false, false, 0, null);
		l.dispatchEvent(e);

		// Do a no-op IPC call to make sure that the processing of the above
		// `endlessipc://window.open` request is complete, so we know
		// `__endless.openedTabs[id]` will be filled in below.
		__endless.ipcAndWaitForReply("noop");

		// If this call was trigged by a non-touch/click, `__endless.openedTabs[id].opened`
		// will be in its default state of `false`.

		if (!__endless.openedTabs[id].opened) {
			console.error("window failed to open");
			/* TODO: send url to ipc anyway to show popup blocker notice */
			return null;
		}

		if (name !== undefined && name != '')
			__endless.openedTabs[id].name = name;
		if (url !== undefined && url != '')
			__endless.openedTabs[id].location = __endless.absoluteURL(url);

		window.event.preventDefault();
		window.event.stopImmediatePropagation();

		return __endless.openedTabs[id];
	};

	// Override `window.close()` so that we can use IPC to ObjC to request that this tab be closed.
	window.close = function () {
		__endless.ipcAndWaitForReply("window.close");
	};

	// Override `console.log()` (etc.) in order to use IPC to send log info to ObjC.
	console._log = function(urg, args) {
		if (args.length == 1)
			args = args[0];
		__endless.ipc("console.log/" + urg + "?" + encodeURIComponent(JSON.stringify(args)));
	};
	console.log = function() { console._log("log", arguments); };
	console.debug = function() { console._log("debug", arguments); };
	console.info = function() { console._log("info", arguments); };
	console.warn = function() { console._log("warn", arguments); };
	console.error = function() { console._log("error", arguments); };

	if (document.readyState == "complete" || document.readyState == "interactive")
		__endless.onLoad();
	else
		document.addEventListener("DOMContentLoaded", __endless.onLoad, false);
}());
}
