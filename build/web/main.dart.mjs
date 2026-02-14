// Compiles a dart2wasm-generated main module from `source` which can then
// instantiatable via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm modules from `bytes` which is then
// instantiatable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export async function instantiate(modulePromise, importObjectPromise) {
  var moduleOrCompiledApp = await modulePromise;
  if (!(moduleOrCompiledApp instanceof CompiledApp)) {
    moduleOrCompiledApp = new CompiledApp(moduleOrCompiledApp);
  }
  const instantiatedApp = await moduleOrCompiledApp.instantiate(await importObjectPromise);
  return instantiatedApp.instantiatedModule;
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export const invoke = (moduleInstance, ...args) => {
  moduleInstance.exports.$invokeMain(args);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredWasm` is a JS function that takes a module name matching a
  //   wasm file produced by the dart2wasm compiler and returns the bytes to
  //   load the module. These bytes can be in either a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  // `loadDynamicModule` is a JS function that takes two string names matching,
  //   in order, a wasm file produced by the dart2wasm compiler during dynamic
  //   module compilation and a corresponding js file produced by the same
  //   compilation. It should return a JS Array containing 2 elements. The first
  //   should be the bytes for the wasm module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The second
  //   should be the result of using the JS 'import' API on the js file path.
  async instantiate(additionalImports, {loadDeferredWasm, loadDynamicModule} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            _4: (o, c) => o instanceof c,
      _6: (o,s,v) => o[s] = v,
      _7: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._7(f,arguments.length,x0) }),
      _8: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._8(f,arguments.length,x0,x1) }),
      _36: () => new Array(),
      _37: x0 => new Array(x0),
      _39: x0 => x0.length,
      _41: (x0,x1) => x0[x1],
      _42: (x0,x1,x2) => { x0[x1] = x2 },
      _43: x0 => new Promise(x0),
      _45: (x0,x1,x2) => new DataView(x0,x1,x2),
      _47: x0 => new Int8Array(x0),
      _48: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      _49: x0 => new Uint8Array(x0),
      _51: x0 => new Uint8ClampedArray(x0),
      _53: x0 => new Int16Array(x0),
      _55: x0 => new Uint16Array(x0),
      _57: x0 => new Int32Array(x0),
      _59: x0 => new Uint32Array(x0),
      _61: x0 => new Float32Array(x0),
      _63: x0 => new Float64Array(x0),
      _65: (x0,x1,x2) => x0.call(x1,x2),
      _66: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._66(f,arguments.length,x0,x1) }),
      _69: () => Symbol("jsBoxedDartObjectProperty"),
      _70: (decoder, codeUnits) => decoder.decode(codeUnits),
      _71: () => new TextDecoder("utf-8", {fatal: true}),
      _72: () => new TextDecoder("utf-8", {fatal: false}),
      _73: (s) => +s,
      _74: x0 => new Uint8Array(x0),
      _75: (x0,x1,x2) => x0.set(x1,x2),
      _76: (x0,x1) => x0.transferFromImageBitmap(x1),
      _78: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._78(f,arguments.length,x0) }),
      _79: x0 => new window.FinalizationRegistry(x0),
      _80: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      _81: (x0,x1) => x0.unregister(x1),
      _82: (x0,x1,x2) => x0.slice(x1,x2),
      _83: (x0,x1) => x0.decode(x1),
      _84: (x0,x1) => x0.segment(x1),
      _85: () => new TextDecoder(),
      _86: (x0,x1) => x0.get(x1),
      _87: x0 => x0.click(),
      _88: x0 => x0.buffer,
      _89: x0 => x0.wasmMemory,
      _90: () => globalThis.window._flutter_skwasmInstance,
      _91: x0 => x0.rasterStartMilliseconds,
      _92: x0 => x0.rasterEndMilliseconds,
      _93: x0 => x0.imageBitmaps,
      _120: x0 => x0.remove(),
      _121: (x0,x1) => x0.append(x1),
      _122: (x0,x1,x2) => x0.insertBefore(x1,x2),
      _123: (x0,x1) => x0.querySelector(x1),
      _125: (x0,x1) => x0.removeChild(x1),
      _203: x0 => x0.stopPropagation(),
      _204: x0 => x0.preventDefault(),
      _206: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _251: x0 => x0.unlock(),
      _252: x0 => x0.getReader(),
      _253: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _254: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      _255: (x0,x1) => x0.item(x1),
      _256: x0 => x0.next(),
      _257: x0 => x0.now(),
      _258: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._258(f,arguments.length,x0) }),
      _259: (x0,x1) => x0.addListener(x1),
      _260: (x0,x1) => x0.removeListener(x1),
      _261: (x0,x1) => x0.matchMedia(x1),
      _262: (x0,x1) => x0.revokeObjectURL(x1),
      _263: x0 => x0.close(),
      _264: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      _265: x0 => new window.ImageDecoder(x0),
      _266: x0 => ({frameIndex: x0}),
      _267: (x0,x1) => x0.decode(x1),
      _268: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._268(f,arguments.length,x0) }),
      _269: (x0,x1) => x0.getModifierState(x1),
      _270: (x0,x1) => x0.removeProperty(x1),
      _271: (x0,x1) => x0.prepend(x1),
      _272: x0 => x0.disconnect(),
      _273: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._273(f,arguments.length,x0) }),
      _274: (x0,x1) => x0.getAttribute(x1),
      _275: (x0,x1) => x0.contains(x1),
      _276: x0 => x0.blur(),
      _277: x0 => x0.hasFocus(),
      _278: (x0,x1) => x0.hasAttribute(x1),
      _279: (x0,x1) => x0.getModifierState(x1),
      _280: (x0,x1) => x0.appendChild(x1),
      _281: (x0,x1) => x0.createTextNode(x1),
      _282: (x0,x1) => x0.removeAttribute(x1),
      _283: x0 => x0.getBoundingClientRect(),
      _284: (x0,x1) => x0.observe(x1),
      _285: x0 => x0.disconnect(),
      _286: (x0,x1) => x0.closest(x1),
      _696: () => globalThis.window.flutterConfiguration,
      _697: x0 => x0.assetBase,
      _703: x0 => x0.debugShowSemanticsNodes,
      _704: x0 => x0.hostElement,
      _705: x0 => x0.multiViewEnabled,
      _706: x0 => x0.nonce,
      _708: x0 => x0.fontFallbackBaseUrl,
      _712: x0 => x0.console,
      _713: x0 => x0.devicePixelRatio,
      _714: x0 => x0.document,
      _715: x0 => x0.history,
      _716: x0 => x0.innerHeight,
      _717: x0 => x0.innerWidth,
      _718: x0 => x0.location,
      _719: x0 => x0.navigator,
      _720: x0 => x0.visualViewport,
      _721: x0 => x0.performance,
      _723: x0 => x0.URL,
      _725: (x0,x1) => x0.getComputedStyle(x1),
      _726: x0 => x0.screen,
      _727: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._727(f,arguments.length,x0) }),
      _728: (x0,x1) => x0.requestAnimationFrame(x1),
      _733: (x0,x1) => x0.warn(x1),
      _735: (x0,x1) => x0.debug(x1),
      _736: x0 => globalThis.parseFloat(x0),
      _737: () => globalThis.window,
      _738: () => globalThis.Intl,
      _739: () => globalThis.Symbol,
      _740: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      _742: x0 => x0.clipboard,
      _743: x0 => x0.maxTouchPoints,
      _744: x0 => x0.vendor,
      _745: x0 => x0.language,
      _746: x0 => x0.platform,
      _747: x0 => x0.userAgent,
      _748: (x0,x1) => x0.vibrate(x1),
      _749: x0 => x0.languages,
      _750: x0 => x0.documentElement,
      _751: (x0,x1) => x0.querySelector(x1),
      _754: (x0,x1) => x0.createElement(x1),
      _757: (x0,x1) => x0.createEvent(x1),
      _758: x0 => x0.activeElement,
      _761: x0 => x0.head,
      _762: x0 => x0.body,
      _764: (x0,x1) => { x0.title = x1 },
      _767: x0 => x0.visibilityState,
      _768: () => globalThis.document,
      _769: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._769(f,arguments.length,x0) }),
      _770: (x0,x1) => x0.dispatchEvent(x1),
      _778: x0 => x0.target,
      _780: x0 => x0.timeStamp,
      _781: x0 => x0.type,
      _783: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      _790: x0 => x0.firstChild,
      _794: x0 => x0.parentElement,
      _796: (x0,x1) => { x0.textContent = x1 },
      _797: x0 => x0.parentNode,
      _799: x0 => x0.isConnected,
      _803: x0 => x0.firstElementChild,
      _805: x0 => x0.nextElementSibling,
      _806: x0 => x0.clientHeight,
      _807: x0 => x0.clientWidth,
      _808: x0 => x0.offsetHeight,
      _809: x0 => x0.offsetWidth,
      _810: x0 => x0.id,
      _811: (x0,x1) => { x0.id = x1 },
      _814: (x0,x1) => { x0.spellcheck = x1 },
      _815: x0 => x0.tagName,
      _816: x0 => x0.style,
      _818: (x0,x1) => x0.querySelectorAll(x1),
      _819: (x0,x1,x2) => x0.setAttribute(x1,x2),
      _820: x0 => x0.tabIndex,
      _821: (x0,x1) => { x0.tabIndex = x1 },
      _822: (x0,x1) => x0.focus(x1),
      _823: x0 => x0.scrollTop,
      _824: (x0,x1) => { x0.scrollTop = x1 },
      _825: x0 => x0.scrollLeft,
      _826: (x0,x1) => { x0.scrollLeft = x1 },
      _827: x0 => x0.classList,
      _829: (x0,x1) => { x0.className = x1 },
      _831: (x0,x1) => x0.getElementsByClassName(x1),
      _832: (x0,x1) => x0.attachShadow(x1),
      _835: x0 => x0.computedStyleMap(),
      _836: (x0,x1) => x0.get(x1),
      _842: (x0,x1) => x0.getPropertyValue(x1),
      _843: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      _844: x0 => x0.offsetLeft,
      _845: x0 => x0.offsetTop,
      _846: x0 => x0.offsetParent,
      _848: (x0,x1) => { x0.name = x1 },
      _849: x0 => x0.content,
      _850: (x0,x1) => { x0.content = x1 },
      _854: (x0,x1) => { x0.src = x1 },
      _855: x0 => x0.naturalWidth,
      _856: x0 => x0.naturalHeight,
      _860: (x0,x1) => { x0.crossOrigin = x1 },
      _862: (x0,x1) => { x0.decoding = x1 },
      _863: x0 => x0.decode(),
      _868: (x0,x1) => { x0.nonce = x1 },
      _873: (x0,x1) => { x0.width = x1 },
      _875: (x0,x1) => { x0.height = x1 },
      _878: (x0,x1) => x0.getContext(x1),
      _940: (x0,x1) => x0.fetch(x1),
      _941: x0 => x0.status,
      _942: x0 => x0.headers,
      _943: x0 => x0.body,
      _944: x0 => x0.arrayBuffer(),
      _947: x0 => x0.read(),
      _948: x0 => x0.value,
      _949: x0 => x0.done,
      _951: x0 => x0.name,
      _952: x0 => x0.x,
      _953: x0 => x0.y,
      _956: x0 => x0.top,
      _957: x0 => x0.right,
      _958: x0 => x0.bottom,
      _959: x0 => x0.left,
      _971: x0 => x0.height,
      _972: x0 => x0.width,
      _973: x0 => x0.scale,
      _974: (x0,x1) => { x0.value = x1 },
      _977: (x0,x1) => { x0.placeholder = x1 },
      _979: (x0,x1) => { x0.name = x1 },
      _980: x0 => x0.selectionDirection,
      _981: x0 => x0.selectionStart,
      _982: x0 => x0.selectionEnd,
      _985: x0 => x0.value,
      _987: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _988: x0 => x0.readText(),
      _989: (x0,x1) => x0.writeText(x1),
      _991: x0 => x0.altKey,
      _992: x0 => x0.code,
      _993: x0 => x0.ctrlKey,
      _994: x0 => x0.key,
      _995: x0 => x0.keyCode,
      _996: x0 => x0.location,
      _997: x0 => x0.metaKey,
      _998: x0 => x0.repeat,
      _999: x0 => x0.shiftKey,
      _1000: x0 => x0.isComposing,
      _1002: x0 => x0.state,
      _1003: (x0,x1) => x0.go(x1),
      _1005: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      _1006: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      _1007: x0 => x0.pathname,
      _1008: x0 => x0.search,
      _1009: x0 => x0.hash,
      _1013: x0 => x0.state,
      _1016: (x0,x1) => x0.createObjectURL(x1),
      _1018: x0 => new Blob(x0),
      _1020: x0 => new MutationObserver(x0),
      _1021: (x0,x1,x2) => x0.observe(x1,x2),
      _1022: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1022(f,arguments.length,x0,x1) }),
      _1025: x0 => x0.attributeName,
      _1026: x0 => x0.type,
      _1027: x0 => x0.matches,
      _1028: x0 => x0.matches,
      _1032: x0 => x0.relatedTarget,
      _1034: x0 => x0.clientX,
      _1035: x0 => x0.clientY,
      _1036: x0 => x0.offsetX,
      _1037: x0 => x0.offsetY,
      _1040: x0 => x0.button,
      _1041: x0 => x0.buttons,
      _1042: x0 => x0.ctrlKey,
      _1046: x0 => x0.pointerId,
      _1047: x0 => x0.pointerType,
      _1048: x0 => x0.pressure,
      _1049: x0 => x0.tiltX,
      _1050: x0 => x0.tiltY,
      _1051: x0 => x0.getCoalescedEvents(),
      _1054: x0 => x0.deltaX,
      _1055: x0 => x0.deltaY,
      _1056: x0 => x0.wheelDeltaX,
      _1057: x0 => x0.wheelDeltaY,
      _1058: x0 => x0.deltaMode,
      _1065: x0 => x0.changedTouches,
      _1068: x0 => x0.clientX,
      _1069: x0 => x0.clientY,
      _1072: x0 => x0.data,
      _1075: (x0,x1) => { x0.disabled = x1 },
      _1077: (x0,x1) => { x0.type = x1 },
      _1078: (x0,x1) => { x0.max = x1 },
      _1079: (x0,x1) => { x0.min = x1 },
      _1080: x0 => x0.value,
      _1081: (x0,x1) => { x0.value = x1 },
      _1082: x0 => x0.disabled,
      _1083: (x0,x1) => { x0.disabled = x1 },
      _1085: (x0,x1) => { x0.placeholder = x1 },
      _1087: (x0,x1) => { x0.name = x1 },
      _1089: (x0,x1) => { x0.autocomplete = x1 },
      _1090: x0 => x0.selectionDirection,
      _1092: x0 => x0.selectionStart,
      _1093: x0 => x0.selectionEnd,
      _1096: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _1097: (x0,x1) => x0.add(x1),
      _1100: (x0,x1) => { x0.noValidate = x1 },
      _1101: (x0,x1) => { x0.method = x1 },
      _1102: (x0,x1) => { x0.action = x1 },
      _1128: x0 => x0.orientation,
      _1129: x0 => x0.width,
      _1130: x0 => x0.height,
      _1131: (x0,x1) => x0.lock(x1),
      _1150: x0 => new ResizeObserver(x0),
      _1153: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1153(f,arguments.length,x0,x1) }),
      _1161: x0 => x0.length,
      _1162: x0 => x0.iterator,
      _1163: x0 => x0.Segmenter,
      _1164: x0 => x0.v8BreakIterator,
      _1165: (x0,x1) => new Intl.Segmenter(x0,x1),
      _1166: x0 => x0.done,
      _1167: x0 => x0.value,
      _1168: x0 => x0.index,
      _1172: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      _1173: (x0,x1) => x0.adoptText(x1),
      _1174: x0 => x0.first(),
      _1175: x0 => x0.next(),
      _1176: x0 => x0.current(),
      _1182: x0 => x0.hostElement,
      _1183: x0 => x0.viewConstraints,
      _1186: x0 => x0.maxHeight,
      _1187: x0 => x0.maxWidth,
      _1188: x0 => x0.minHeight,
      _1189: x0 => x0.minWidth,
      _1190: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1190(f,arguments.length,x0) }),
      _1191: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1191(f,arguments.length,x0) }),
      _1192: (x0,x1) => ({addView: x0,removeView: x1}),
      _1193: x0 => x0.loader,
      _1194: () => globalThis._flutter,
      _1195: (x0,x1) => x0.didCreateEngineInitializer(x1),
      _1196: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1196(f,arguments.length,x0) }),
      _1197: f => finalizeWrapper(f, function() { return dartInstance.exports._1197(f,arguments.length) }),
      _1198: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      _1199: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1199(f,arguments.length,x0) }),
      _1200: x0 => ({runApp: x0}),
      _1201: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1201(f,arguments.length,x0,x1) }),
      _1202: x0 => x0.length,
      _1203: () => globalThis.window.ImageDecoder,
      _1204: x0 => x0.tracks,
      _1206: x0 => x0.completed,
      _1208: x0 => x0.image,
      _1214: x0 => x0.displayWidth,
      _1215: x0 => x0.displayHeight,
      _1216: x0 => x0.duration,
      _1219: x0 => x0.ready,
      _1220: x0 => x0.selectedTrack,
      _1221: x0 => x0.repetitionCount,
      _1222: x0 => x0.frameCount,
      _1265: x0 => x0.requestFullscreen(),
      _1266: x0 => x0.exitFullscreen(),
      _1272: (x0,x1) => x0.createElement(x1),
      _1278: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _1279: f => finalizeWrapper(f, function(x0,x1,x2) { return dartInstance.exports._1279(f,arguments.length,x0,x1,x2) }),
      _1280: (x0,x1) => x0.append(x1),
      _1282: x0 => x0.remove(),
      _1283: (x0,x1,x2) => x0.setAttribute(x1,x2),
      _1284: (x0,x1) => x0.removeAttribute(x1),
      _1286: (x0,x1) => x0.getResponseHeader(x1),
      _1309: (x0,x1) => x0.item(x1),
      _1312: (x0,x1) => { x0.csp = x1 },
      _1313: x0 => x0.csp,
      _1314: (x0,x1) => x0.getCookieExpirationDate(x1),
      _1315: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1315(f,arguments.length,x0) }),
      _1316: x0 => ({createScriptURL: x0}),
      _1317: (x0,x1,x2) => x0.createPolicy(x1,x2),
      _1318: (x0,x1,x2) => x0.createScriptURL(x1,x2),
      _1319: x0 => x0.hasChildNodes(),
      _1320: (x0,x1,x2) => x0.insertBefore(x1,x2),
      _1321: (x0,x1) => x0.querySelectorAll(x1),
      _1322: (x0,x1) => x0.item(x1),
      _1323: x0 => globalThis.Sentry.init(x0),
      _1324: () => new Sentry.getClient(),
      _1325: x0 => x0.getOptions(),
      _1329: () => globalThis.Sentry.globalHandlersIntegration(),
      _1330: () => globalThis.Sentry.dedupeIntegration(),
      _1331: () => globalThis.Sentry.close(),
      _1332: (x0,x1) => x0.sendEnvelope(x1),
      _1335: () => globalThis.globalThis,
      _1337: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _1338: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      _1339: (x0,x1) => x0.createElement(x1),
      _1344: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1349: x0 => globalThis.URL.createObjectURL(x0),
      _1352: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1352(f,arguments.length,x0) }),
      _1353: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1353(f,arguments.length,x0) }),
      _1354: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1354(f,arguments.length,x0) }),
      _1355: (x0,x1) => x0.querySelector(x1),
      _1356: (x0,x1) => x0.replaceChildren(x1),
      _1357: x0 => x0.click(),
      _1358: (x0,x1) => x0.add(x1),
      _1359: (x0,x1) => x0.remove(x1),
      _1360: (x0,x1) => x0.item(x1),
      _1361: (x0,x1) => x0.contains(x1),
      _1362: (x0,x1) => x0.createTextNode(x1),
      _1363: (x0,x1) => x0.appendChild(x1),
      _1364: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1364(f,arguments.length,x0) }),
      _1365: x0 => x0.stopPropagation(),
      _1366: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1366(f,arguments.length,x0) }),
      _1367: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _1368: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1368(f,arguments.length,x0) }),
      _1369: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1369(f,arguments.length,x0) }),
      _1370: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1370(f,arguments.length,x0) }),
      _1371: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1371(f,arguments.length,x0) }),
      _1372: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1372(f,arguments.length,x0) }),
      _1373: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1373(f,arguments.length,x0) }),
      _1374: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1374(f,arguments.length,x0) }),
      _1375: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1375(f,arguments.length,x0) }),
      _1376: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1376(f,arguments.length,x0) }),
      _1377: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1377(f,arguments.length,x0) }),
      _1378: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1378(f,arguments.length,x0) }),
      _1379: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1379(f,arguments.length,x0) }),
      _1380: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1380(f,arguments.length,x0) }),
      _1381: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1381(f,arguments.length,x0) }),
      _1382: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1382(f,arguments.length,x0) }),
      _1383: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1383(f,arguments.length,x0) }),
      _1384: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1384(f,arguments.length,x0) }),
      _1385: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1385(f,arguments.length,x0) }),
      _1396: x0 => ({merge: x0}),
      _1398: x0 => new firebase_firestore.FieldPath(x0),
      _1399: (x0,x1) => new firebase_firestore.FieldPath(x0,x1),
      _1400: (x0,x1,x2) => new firebase_firestore.FieldPath(x0,x1,x2),
      _1401: (x0,x1,x2,x3) => new firebase_firestore.FieldPath(x0,x1,x2,x3),
      _1402: (x0,x1,x2,x3,x4) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4),
      _1403: (x0,x1,x2,x3,x4,x5) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5),
      _1404: (x0,x1,x2,x3,x4,x5,x6) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6),
      _1405: (x0,x1,x2,x3,x4,x5,x6,x7) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7),
      _1406: (x0,x1,x2,x3,x4,x5,x6,x7,x8) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8),
      _1407: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8,x9),
      _1408: () => globalThis.firebase_firestore.documentId(),
      _1409: (x0,x1) => new firebase_firestore.GeoPoint(x0,x1),
      _1410: x0 => globalThis.firebase_firestore.vector(x0),
      _1411: x0 => globalThis.firebase_firestore.Bytes.fromUint8Array(x0),
      _1413: (x0,x1) => globalThis.firebase_firestore.collection(x0,x1),
      _1415: (x0,x1) => globalThis.firebase_firestore.doc(x0,x1),
      _1418: x0 => x0.call(),
      _1456: (x0,x1,x2) => globalThis.firebase_firestore.setDoc(x0,x1,x2),
      _1457: (x0,x1) => globalThis.firebase_firestore.setDoc(x0,x1),
      _1471: x0 => globalThis.firebase_firestore.doc(x0),
      _1495: (x0,x1) => globalThis.firebase_firestore.getFirestore(x0,x1),
      _1497: x0 => globalThis.firebase_firestore.Timestamp.fromMillis(x0),
      _1498: f => finalizeWrapper(f, function() { return dartInstance.exports._1498(f,arguments.length) }),
      _1522: x0 => x0.path,
      _1545: x0 => x0.path,
      _1625: x0 => x0.load(),
      _1626: x0 => x0.play(),
      _1627: x0 => x0.pause(),
      _1631: (x0,x1) => x0.end(x1),
      _1632: x0 => x0.decode(),
      _1633: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1634: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      _1635: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1635(f,arguments.length,x0) }),
      _1636: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1636(f,arguments.length,x0) }),
      _1637: x0 => x0.send(),
      _1638: () => new XMLHttpRequest(),
      _1639: x0 => globalThis.Wakelock.toggle(x0),
      _1650: (x0,x1) => x0.getIdToken(x1),
      _1659: x0 => x0.reload(),
      _1666: (x0,x1) => globalThis.firebase_auth.updateProfile(x0,x1),
      _1669: x0 => x0.toJSON(),
      _1670: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1670(f,arguments.length,x0) }),
      _1671: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1671(f,arguments.length,x0) }),
      _1672: (x0,x1,x2) => x0.onAuthStateChanged(x1,x2),
      _1673: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1673(f,arguments.length,x0) }),
      _1674: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1674(f,arguments.length,x0) }),
      _1675: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1675(f,arguments.length,x0) }),
      _1676: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1676(f,arguments.length,x0) }),
      _1677: (x0,x1,x2) => x0.onIdTokenChanged(x1,x2),
      _1681: (x0,x1,x2) => globalThis.firebase_auth.createUserWithEmailAndPassword(x0,x1,x2),
      _1691: (x0,x1,x2) => globalThis.firebase_auth.signInWithEmailAndPassword(x0,x1,x2),
      _1696: x0 => x0.signOut(),
      _1697: (x0,x1) => globalThis.firebase_auth.connectAuthEmulator(x0,x1),
      _1720: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromResult(x0),
      _1735: x0 => globalThis.firebase_auth.getAdditionalUserInfo(x0),
      _1736: (x0,x1,x2) => ({errorMap: x0,persistence: x1,popupRedirectResolver: x2}),
      _1737: (x0,x1) => globalThis.firebase_auth.initializeAuth(x0,x1),
      _1743: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromError(x0),
      _1746: (x0,x1) => ({displayName: x0,photoURL: x1}),
      _1758: () => globalThis.firebase_auth.debugErrorMap,
      _1761: () => globalThis.firebase_auth.browserSessionPersistence,
      _1763: () => globalThis.firebase_auth.browserLocalPersistence,
      _1765: () => globalThis.firebase_auth.indexedDBLocalPersistence,
      _1768: x0 => globalThis.firebase_auth.multiFactor(x0),
      _1769: (x0,x1) => globalThis.firebase_auth.getMultiFactorResolver(x0,x1),
      _1771: x0 => x0.currentUser,
      _1775: x0 => x0.tenantId,
      _1785: x0 => x0.displayName,
      _1786: x0 => x0.email,
      _1787: x0 => x0.phoneNumber,
      _1788: x0 => x0.photoURL,
      _1789: x0 => x0.providerId,
      _1790: x0 => x0.uid,
      _1791: x0 => x0.emailVerified,
      _1792: x0 => x0.isAnonymous,
      _1793: x0 => x0.providerData,
      _1794: x0 => x0.refreshToken,
      _1795: x0 => x0.tenantId,
      _1796: x0 => x0.metadata,
      _1798: x0 => x0.providerId,
      _1799: x0 => x0.signInMethod,
      _1800: x0 => x0.accessToken,
      _1801: x0 => x0.idToken,
      _1802: x0 => x0.secret,
      _1813: x0 => x0.creationTime,
      _1814: x0 => x0.lastSignInTime,
      _1819: x0 => x0.code,
      _1821: x0 => x0.message,
      _1833: x0 => x0.email,
      _1834: x0 => x0.phoneNumber,
      _1835: x0 => x0.tenantId,
      _1858: x0 => x0.user,
      _1861: x0 => x0.providerId,
      _1862: x0 => x0.profile,
      _1863: x0 => x0.username,
      _1864: x0 => x0.isNewUser,
      _1867: () => globalThis.firebase_auth.browserPopupRedirectResolver,
      _1872: x0 => x0.displayName,
      _1873: x0 => x0.enrollmentTime,
      _1874: x0 => x0.factorId,
      _1875: x0 => x0.uid,
      _1877: x0 => x0.hints,
      _1878: x0 => x0.session,
      _1880: x0 => x0.phoneNumber,
      _1890: x0 => ({displayName: x0}),
      _1891: x0 => ({photoURL: x0}),
      _1892: (x0,x1) => x0.getItem(x1),
      _1896: (x0,x1) => x0.getElementById(x1),
      _1898: (x0,x1) => x0.removeItem(x1),
      _1899: (x0,x1,x2) => x0.setItem(x1,x2),
      _1913: () => globalThis.firebase_core.getApps(),
      _1914: (x0,x1,x2,x3,x4,x5,x6,x7) => ({apiKey: x0,authDomain: x1,databaseURL: x2,projectId: x3,storageBucket: x4,messagingSenderId: x5,measurementId: x6,appId: x7}),
      _1915: (x0,x1) => globalThis.firebase_core.initializeApp(x0,x1),
      _1916: x0 => globalThis.firebase_core.getApp(x0),
      _1917: () => globalThis.firebase_core.getApp(),
      _2038: () => globalThis.firebase_core.SDK_VERSION,
      _2044: x0 => x0.apiKey,
      _2046: x0 => x0.authDomain,
      _2048: x0 => x0.databaseURL,
      _2050: x0 => x0.projectId,
      _2052: x0 => x0.storageBucket,
      _2054: x0 => x0.messagingSenderId,
      _2056: x0 => x0.measurementId,
      _2058: x0 => x0.appId,
      _2060: x0 => x0.name,
      _2061: x0 => x0.options,
      _2064: (x0,x1) => x0.debug(x1),
      _2065: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2065(f,arguments.length,x0) }),
      _2066: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._2066(f,arguments.length,x0,x1) }),
      _2067: (x0,x1) => ({createScript: x0,createScriptURL: x1}),
      _2068: (x0,x1) => x0.createScriptURL(x1),
      _2069: (x0,x1,x2) => x0.createScript(x1,x2),
      _2070: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2070(f,arguments.length,x0) }),
      _2071: () => globalThis.removeSplashFromWeb(),
      _2073: Date.now,
      _2074: secondsSinceEpoch => {
        const date = new Date(secondsSinceEpoch * 1000);
        const match = /\((.*)\)/.exec(date.toString());
        if (match == null) {
            // This should never happen on any recent browser.
            return '';
        }
        return match[1];
      },
      _2075: s => new Date(s * 1000).getTimezoneOffset() * 60,
      _2076: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      _2077: () => {
        let stackString = new Error().stack.toString();
        let frames = stackString.split('\n');
        let drop = 2;
        if (frames[0] === 'Error') {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      _2078: () => typeof dartUseDateNowForTicks !== "undefined",
      _2079: () => 1000 * performance.now(),
      _2080: () => Date.now(),
      _2081: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      _2082: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      _2083: () => new WeakMap(),
      _2084: (map, o) => map.get(o),
      _2085: (map, o, v) => map.set(o, v),
      _2086: x0 => new WeakRef(x0),
      _2087: x0 => x0.deref(),
      _2088: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2088(f,arguments.length,x0) }),
      _2089: x0 => new FinalizationRegistry(x0),
      _2091: (x0,x1,x2) => x0.register(x1,x2),
      _2094: () => globalThis.WeakRef,
      _2095: () => globalThis.FinalizationRegistry,
      _2097: s => JSON.stringify(s),
      _2098: s => printToConsole(s),
      _2099: (o, p, r) => o.replaceAll(p, () => r),
      _2100: (o, p, r) => o.replace(p, () => r),
      _2101: Function.prototype.call.bind(String.prototype.toLowerCase),
      _2102: s => s.toUpperCase(),
      _2103: s => s.trim(),
      _2104: s => s.trimLeft(),
      _2105: s => s.trimRight(),
      _2106: (string, times) => string.repeat(times),
      _2107: Function.prototype.call.bind(String.prototype.indexOf),
      _2108: (s, p, i) => s.lastIndexOf(p, i),
      _2109: (string, token) => string.split(token),
      _2110: Object.is,
      _2111: o => o instanceof Array,
      _2112: (a, i) => a.push(i),
      _2115: (a, l) => a.length = l,
      _2116: a => a.pop(),
      _2117: (a, i) => a.splice(i, 1),
      _2118: (a, s) => a.join(s),
      _2119: (a, s, e) => a.slice(s, e),
      _2120: (a, s, e) => a.splice(s, e),
      _2121: (a, b) => a == b ? 0 : (a > b ? 1 : -1),
      _2122: a => a.length,
      _2123: (a, l) => a.length = l,
      _2124: (a, i) => a[i],
      _2125: (a, i, v) => a[i] = v,
      _2126: (a, t) => a.concat(t),
      _2127: o => {
        if (o instanceof ArrayBuffer) return 0;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 1;
        }
        return 2;
      },
      _2128: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      _2130: o => o instanceof Uint8Array,
      _2131: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      _2132: o => o instanceof Int8Array,
      _2133: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      _2134: o => o instanceof Uint8ClampedArray,
      _2135: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      _2136: o => o instanceof Uint16Array,
      _2137: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      _2138: o => o instanceof Int16Array,
      _2139: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      _2140: o => o instanceof Uint32Array,
      _2141: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      _2142: o => o instanceof Int32Array,
      _2143: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      _2145: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      _2146: o => o instanceof Float32Array,
      _2147: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      _2148: o => o instanceof Float64Array,
      _2149: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      _2150: (t, s) => t.set(s),
      _2151: l => new DataView(new ArrayBuffer(l)),
      _2152: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      _2154: o => o.buffer,
      _2155: o => o.byteOffset,
      _2156: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      _2157: (b, o) => new DataView(b, o),
      _2158: (b, o, l) => new DataView(b, o, l),
      _2159: Function.prototype.call.bind(DataView.prototype.getUint8),
      _2160: Function.prototype.call.bind(DataView.prototype.setUint8),
      _2161: Function.prototype.call.bind(DataView.prototype.getInt8),
      _2162: Function.prototype.call.bind(DataView.prototype.setInt8),
      _2163: Function.prototype.call.bind(DataView.prototype.getUint16),
      _2164: Function.prototype.call.bind(DataView.prototype.setUint16),
      _2165: Function.prototype.call.bind(DataView.prototype.getInt16),
      _2166: Function.prototype.call.bind(DataView.prototype.setInt16),
      _2167: Function.prototype.call.bind(DataView.prototype.getUint32),
      _2168: Function.prototype.call.bind(DataView.prototype.setUint32),
      _2169: Function.prototype.call.bind(DataView.prototype.getInt32),
      _2170: Function.prototype.call.bind(DataView.prototype.setInt32),
      _2173: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      _2174: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      _2175: Function.prototype.call.bind(DataView.prototype.getFloat32),
      _2176: Function.prototype.call.bind(DataView.prototype.setFloat32),
      _2177: Function.prototype.call.bind(DataView.prototype.getFloat64),
      _2178: Function.prototype.call.bind(DataView.prototype.setFloat64),
      _2191: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      _2192: (handle) => clearTimeout(handle),
      _2193: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      _2194: (handle) => clearInterval(handle),
      _2195: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      _2196: () => Date.now(),
      _2201: o => Object.keys(o),
      _2202: x0 => x0.deviceMemory,
      _2203: (x0,x1) => x0.append(x1),
      _2204: x0 => ({xhrSetup: x0}),
      _2205: x0 => new Hls(x0),
      _2206: () => globalThis.Hls.isSupported(),
      _2208: (x0,x1) => x0.loadSource(x1),
      _2209: (x0,x1) => x0.attachMedia(x1),
      _2213: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      _2215: (x0,x1) => x0.canPlayType(x1),
      _2218: () => new XMLHttpRequest(),
      _2219: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _2220: x0 => x0.send(),
      _2222: () => new FileReader(),
      _2223: (x0,x1) => x0.readAsArrayBuffer(x1),
      _2224: () => new AbortController(),
      _2225: x0 => x0.abort(),
      _2226: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      _2227: (x0,x1) => globalThis.fetch(x0,x1),
      _2228: (x0,x1) => x0.get(x1),
      _2229: f => finalizeWrapper(f, function(x0,x1,x2) { return dartInstance.exports._2229(f,arguments.length,x0,x1,x2) }),
      _2230: (x0,x1) => x0.forEach(x1),
      _2231: x0 => x0.getReader(),
      _2232: x0 => x0.read(),
      _2233: x0 => x0.cancel(),
      _2235: (x0,x1) => x0.send(x1),
      _2237: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2237(f,arguments.length,x0) }),
      _2238: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2238(f,arguments.length,x0) }),
      _2242: (x0,x1) => x0.matchMedia(x1),
      _2252: () => globalThis.window.flutter_inappwebview,
      _2256: (x0,x1) => { x0.nativeCommunication = x1 },
      _2257: (x0,x1) => x0.key(x1),
      _2258: (x0,x1) => x0.item(x1),
      _2259: x0 => x0.trustedTypes,
      _2260: (x0,x1) => { x0.text = x1 },
      _2268: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      _2269: (x0,x1) => x0.exec(x1),
      _2270: (x0,x1) => x0.test(x1),
      _2271: x0 => x0.pop(),
      _2273: o => o === undefined,
      _2275: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      _2277: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      _2278: o => o instanceof RegExp,
      _2279: (l, r) => l === r,
      _2280: o => o,
      _2281: o => o,
      _2282: o => o,
      _2283: b => !!b,
      _2284: o => o.length,
      _2286: (o, i) => o[i],
      _2287: f => f.dartFunction,
      _2288: () => ({}),
      _2289: () => [],
      _2291: () => globalThis,
      _2292: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      _2293: (o, p) => p in o,
      _2294: (o, p) => o[p],
      _2295: (o, p, v) => o[p] = v,
      _2296: (o, m, a) => o[m].apply(o, a),
      _2298: o => String(o),
      _2299: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      _2300: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        return 18;
      },
      _2301: o => [o],
      _2302: (o0, o1) => [o0, o1],
      _2303: (o0, o1, o2) => [o0, o1, o2],
      _2304: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      _2305: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2306: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2307: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2308: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2309: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2310: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2311: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2312: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2313: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2314: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2315: x0 => new ArrayBuffer(x0),
      _2316: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      _2317: x0 => x0.input,
      _2318: x0 => x0.index,
      _2319: x0 => x0.groups,
      _2320: x0 => x0.flags,
      _2321: x0 => x0.multiline,
      _2322: x0 => x0.ignoreCase,
      _2323: x0 => x0.unicode,
      _2324: x0 => x0.dotAll,
      _2325: (x0,x1) => { x0.lastIndex = x1 },
      _2326: (o, p) => p in o,
      _2327: (o, p) => o[p],
      _2328: (o, p, v) => o[p] = v,
      _2329: (o, p) => delete o[p],
      _2330: x0 => x0.random(),
      _2331: (x0,x1) => x0.getRandomValues(x1),
      _2332: () => globalThis.crypto,
      _2333: () => globalThis.Math,
      _2334: Function.prototype.call.bind(Number.prototype.toString),
      _2335: Function.prototype.call.bind(BigInt.prototype.toString),
      _2336: Function.prototype.call.bind(Number.prototype.toString),
      _2337: (d, digits) => d.toFixed(digits),
      _2341: () => globalThis.document,
      _2347: (x0,x1) => { x0.height = x1 },
      _2349: (x0,x1) => { x0.width = x1 },
      _2358: x0 => x0.style,
      _2361: x0 => x0.src,
      _2362: (x0,x1) => { x0.src = x1 },
      _2363: x0 => x0.naturalWidth,
      _2364: x0 => x0.naturalHeight,
      _2380: x0 => x0.status,
      _2381: (x0,x1) => { x0.responseType = x1 },
      _2383: x0 => x0.response,
      _2428: x0 => x0.status,
      _2431: (x0,x1) => { x0.responseType = x1 },
      _2432: x0 => x0.response,
      _2433: x0 => x0.responseText,
      _2508: x0 => x0.style,
      _2521: (x0,x1) => { x0.oncancel = x1 },
      _2527: (x0,x1) => { x0.onchange = x1 },
      _2567: (x0,x1) => { x0.onerror = x1 },
      _2705: x0 => x0.dataset,
      _2712: (x0,x1) => x0[x1],
      _2984: x0 => x0.src,
      _2985: (x0,x1) => { x0.src = x1 },
      _2988: x0 => x0.name,
      _2989: (x0,x1) => { x0.name = x1 },
      _2990: x0 => x0.sandbox,
      _2991: x0 => x0.allow,
      _2992: (x0,x1) => { x0.allow = x1 },
      _2993: x0 => x0.allowFullscreen,
      _2994: (x0,x1) => { x0.allowFullscreen = x1 },
      _2999: x0 => x0.referrerPolicy,
      _3000: (x0,x1) => { x0.referrerPolicy = x1 },
      _3080: x0 => x0.videoWidth,
      _3081: x0 => x0.videoHeight,
      _3110: x0 => x0.error,
      _3112: (x0,x1) => { x0.src = x1 },
      _3121: x0 => x0.buffered,
      _3124: x0 => x0.currentTime,
      _3125: (x0,x1) => { x0.currentTime = x1 },
      _3126: x0 => x0.duration,
      _3127: x0 => x0.paused,
      _3130: x0 => x0.playbackRate,
      _3142: (x0,x1) => { x0.controls = x1 },
      _3143: x0 => x0.volume,
      _3144: (x0,x1) => { x0.volume = x1 },
      _3145: x0 => x0.muted,
      _3146: (x0,x1) => { x0.muted = x1 },
      _3162: x0 => x0.message,
      _3235: x0 => x0.length,
      _3431: (x0,x1) => { x0.accept = x1 },
      _3445: x0 => x0.files,
      _3471: (x0,x1) => { x0.multiple = x1 },
      _3489: (x0,x1) => { x0.type = x1 },
      _3738: x0 => x0.src,
      _3739: (x0,x1) => { x0.src = x1 },
      _3741: (x0,x1) => { x0.type = x1 },
      _3745: (x0,x1) => { x0.async = x1 },
      _3749: (x0,x1) => { x0.crossOrigin = x1 },
      _3751: (x0,x1) => { x0.text = x1 },
      _3753: (x0,x1) => { x0.integrity = x1 },
      _3759: (x0,x1) => { x0.charset = x1 },
      _4207: () => globalThis.window,
      _4246: x0 => x0.document,
      _4249: x0 => x0.location,
      _4268: x0 => x0.navigator,
      _4272: x0 => x0.screen,
      _4284: x0 => x0.devicePixelRatio,
      _4530: x0 => x0.trustedTypes,
      _4531: x0 => x0.sessionStorage,
      _4532: x0 => x0.localStorage,
      _4542: x0 => x0.origin,
      _4547: x0 => x0.hostname,
      _4551: x0 => x0.pathname,
      _4638: x0 => x0.geolocation,
      _4641: x0 => x0.mediaDevices,
      _4643: x0 => x0.permissions,
      _4654: x0 => x0.platform,
      _4657: x0 => x0.userAgent,
      _4658: x0 => x0.vendor,
      _4663: x0 => x0.onLine,
      _4865: x0 => x0.length,
      _6769: x0 => x0.type,
      _6770: x0 => x0.target,
      _6810: x0 => x0.signal,
      _6819: x0 => x0.length,
      _6821: x0 => x0.length,
      _6862: x0 => x0.baseURI,
      _6868: x0 => x0.firstChild,
      _6875: (x0,x1) => { x0.textContent = x1 },
      _6879: () => globalThis.document,
      _6935: x0 => x0.documentElement,
      _6956: x0 => x0.body,
      _6958: x0 => x0.head,
      _7285: x0 => x0.tagName,
      _7286: x0 => x0.id,
      _7287: (x0,x1) => { x0.id = x1 },
      _7289: (x0,x1) => { x0.className = x1 },
      _7290: x0 => x0.classList,
      _7311: (x0,x1) => { x0.innerHTML = x1 },
      _7314: x0 => x0.children,
      _7514: x0 => x0.length,
      _8629: x0 => x0.value,
      _8631: x0 => x0.done,
      _8811: x0 => x0.size,
      _8812: x0 => x0.type,
      _8819: x0 => x0.name,
      _8820: x0 => x0.lastModified,
      _8825: x0 => x0.length,
      _8831: x0 => x0.result,
      _9328: x0 => x0.url,
      _9330: x0 => x0.status,
      _9332: x0 => x0.statusText,
      _9333: x0 => x0.headers,
      _9334: x0 => x0.body,
      _9601: x0 => x0.type,
      _9616: x0 => x0.matches,
      _9627: x0 => x0.availWidth,
      _9628: x0 => x0.availHeight,
      _9633: x0 => x0.orientation,
      _11411: (x0,x1) => { x0.backgroundColor = x1 },
      _11457: (x0,x1) => { x0.border = x1 },
      _11735: (x0,x1) => { x0.display = x1 },
      _11811: (x0,x1) => { x0.fontSize = x1 },
      _11899: (x0,x1) => { x0.height = x1 },
      _12225: (x0,x1) => { x0.position = x1 },
      _12589: (x0,x1) => { x0.width = x1 },
      _12957: x0 => x0.name,
      _12958: x0 => x0.message,
      _13672: () => globalThis.console,
      _13698: () => globalThis.window.flutterCanvasKit,
      _13699: () => globalThis.window._flutter_skwasmInstance,
      _13700: x0 => x0.name,
      _13701: x0 => x0.message,
      _13702: x0 => x0.code,
      _13704: x0 => x0.customData,
      _13705: () => globalThis.removeSplashFromWeb(),

    };

    const baseImports = {
      dart2wasm: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      S: new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
