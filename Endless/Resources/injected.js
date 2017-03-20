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
		var ipcURL = "endlessipc://window.open/?" + encodeURIComponent(__endless.absoluteURL(url));

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

	if (document.readyState == "complete" || document.readyState == "interactive") {
		__endless.onLoad();
	}
	else {
		document.addEventListener("DOMContentLoaded", __endless.onLoad, false);
	}
}());
}
