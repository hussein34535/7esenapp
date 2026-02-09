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
      _1364: x0 => x0.toArray(),
      _1365: x0 => x0.toUint8Array(),
      _1366: x0 => ({serverTimestamps: x0}),
      _1367: x0 => ({source: x0}),
      _1368: x0 => ({merge: x0}),
      _1370: x0 => new firebase_firestore.FieldPath(x0),
      _1371: (x0,x1) => new firebase_firestore.FieldPath(x0,x1),
      _1372: (x0,x1,x2) => new firebase_firestore.FieldPath(x0,x1,x2),
      _1373: (x0,x1,x2,x3) => new firebase_firestore.FieldPath(x0,x1,x2,x3),
      _1374: (x0,x1,x2,x3,x4) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4),
      _1375: (x0,x1,x2,x3,x4,x5) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5),
      _1376: (x0,x1,x2,x3,x4,x5,x6) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6),
      _1377: (x0,x1,x2,x3,x4,x5,x6,x7) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7),
      _1378: (x0,x1,x2,x3,x4,x5,x6,x7,x8) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8),
      _1379: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8,x9),
      _1380: () => globalThis.firebase_firestore.documentId(),
      _1381: (x0,x1) => new firebase_firestore.GeoPoint(x0,x1),
      _1382: x0 => globalThis.firebase_firestore.vector(x0),
      _1383: x0 => globalThis.firebase_firestore.Bytes.fromUint8Array(x0),
      _1385: (x0,x1) => globalThis.firebase_firestore.collection(x0,x1),
      _1387: (x0,x1) => globalThis.firebase_firestore.doc(x0,x1),
      _1390: x0 => x0.call(),
      _1420: x0 => globalThis.firebase_firestore.getDoc(x0),
      _1421: x0 => globalThis.firebase_firestore.getDocFromServer(x0),
      _1422: x0 => globalThis.firebase_firestore.getDocFromCache(x0),
      _1423: (x0,x1) => ({includeMetadataChanges: x0,source: x1}),
      _1424: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1424(f,arguments.length,x0) }),
      _1425: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1425(f,arguments.length,x0) }),
      _1426: (x0,x1,x2,x3) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2,x3),
      _1427: (x0,x1,x2) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2),
      _1428: (x0,x1,x2) => globalThis.firebase_firestore.setDoc(x0,x1,x2),
      _1429: (x0,x1) => globalThis.firebase_firestore.setDoc(x0,x1),
      _1443: x0 => globalThis.firebase_firestore.doc(x0),
      _1446: (x0,x1) => x0.data(x1),
      _1459: () => globalThis.firebase_firestore.serverTimestamp(),
      _1467: (x0,x1) => globalThis.firebase_firestore.getFirestore(x0,x1),
      _1469: x0 => globalThis.firebase_firestore.Timestamp.fromMillis(x0),
      _1470: f => finalizeWrapper(f, function() { return dartInstance.exports._1470(f,arguments.length) }),
      _1487: () => globalThis.firebase_firestore.updateDoc,
      _1494: x0 => x0.path,
      _1497: () => globalThis.firebase_firestore.GeoPoint,
      _1498: x0 => x0.latitude,
      _1499: x0 => x0.longitude,
      _1501: () => globalThis.firebase_firestore.VectorValue,
      _1502: () => globalThis.firebase_firestore.Bytes,
      _1513: () => globalThis.firebase_firestore.DocumentReference,
      _1517: x0 => x0.path,
      _1526: x0 => x0.metadata,
      _1527: x0 => x0.ref,
      _1538: () => globalThis.firebase_firestore.Timestamp,
      _1539: x0 => x0.seconds,
      _1540: x0 => x0.nanoseconds,
      _1576: x0 => x0.hasPendingWrites,
      _1578: x0 => x0.fromCache,
      _1585: x0 => x0.source,
      _1597: x0 => x0.load(),
      _1598: x0 => x0.play(),
      _1599: x0 => x0.pause(),
      _1604: (x0,x1) => x0.end(x1),
      _1605: x0 => x0.decode(),
      _1606: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1607: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      _1608: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1608(f,arguments.length,x0) }),
      _1609: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1609(f,arguments.length,x0) }),
      _1610: x0 => x0.send(),
      _1611: () => new XMLHttpRequest(),
      _1612: x0 => globalThis.Wakelock.toggle(x0),
      _1623: (x0,x1) => x0.getIdToken(x1),
      _1632: x0 => x0.reload(),
      _1639: (x0,x1) => globalThis.firebase_auth.updateProfile(x0,x1),
      _1642: x0 => x0.toJSON(),
      _1643: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1643(f,arguments.length,x0) }),
      _1644: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1644(f,arguments.length,x0) }),
      _1645: (x0,x1,x2) => x0.onAuthStateChanged(x1,x2),
      _1646: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1646(f,arguments.length,x0) }),
      _1647: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1647(f,arguments.length,x0) }),
      _1648: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1648(f,arguments.length,x0) }),
      _1649: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1649(f,arguments.length,x0) }),
      _1650: (x0,x1,x2) => x0.onIdTokenChanged(x1,x2),
      _1654: (x0,x1,x2) => globalThis.firebase_auth.createUserWithEmailAndPassword(x0,x1,x2),
      _1664: (x0,x1,x2) => globalThis.firebase_auth.signInWithEmailAndPassword(x0,x1,x2),
      _1669: x0 => x0.signOut(),
      _1670: (x0,x1) => globalThis.firebase_auth.connectAuthEmulator(x0,x1),
      _1693: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromResult(x0),
      _1708: x0 => globalThis.firebase_auth.getAdditionalUserInfo(x0),
      _1709: (x0,x1,x2) => ({errorMap: x0,persistence: x1,popupRedirectResolver: x2}),
      _1710: (x0,x1) => globalThis.firebase_auth.initializeAuth(x0,x1),
      _1716: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromError(x0),
      _1719: (x0,x1) => ({displayName: x0,photoURL: x1}),
      _1731: () => globalThis.firebase_auth.debugErrorMap,
      _1734: () => globalThis.firebase_auth.browserSessionPersistence,
      _1736: () => globalThis.firebase_auth.browserLocalPersistence,
      _1738: () => globalThis.firebase_auth.indexedDBLocalPersistence,
      _1741: x0 => globalThis.firebase_auth.multiFactor(x0),
      _1742: (x0,x1) => globalThis.firebase_auth.getMultiFactorResolver(x0,x1),
      _1744: x0 => x0.currentUser,
      _1748: x0 => x0.tenantId,
      _1758: x0 => x0.displayName,
      _1759: x0 => x0.email,
      _1760: x0 => x0.phoneNumber,
      _1761: x0 => x0.photoURL,
      _1762: x0 => x0.providerId,
      _1763: x0 => x0.uid,
      _1764: x0 => x0.emailVerified,
      _1765: x0 => x0.isAnonymous,
      _1766: x0 => x0.providerData,
      _1767: x0 => x0.refreshToken,
      _1768: x0 => x0.tenantId,
      _1769: x0 => x0.metadata,
      _1771: x0 => x0.providerId,
      _1772: x0 => x0.signInMethod,
      _1773: x0 => x0.accessToken,
      _1774: x0 => x0.idToken,
      _1775: x0 => x0.secret,
      _1786: x0 => x0.creationTime,
      _1787: x0 => x0.lastSignInTime,
      _1792: x0 => x0.code,
      _1794: x0 => x0.message,
      _1806: x0 => x0.email,
      _1807: x0 => x0.phoneNumber,
      _1808: x0 => x0.tenantId,
      _1831: x0 => x0.user,
      _1834: x0 => x0.providerId,
      _1835: x0 => x0.profile,
      _1836: x0 => x0.username,
      _1837: x0 => x0.isNewUser,
      _1840: () => globalThis.firebase_auth.browserPopupRedirectResolver,
      _1845: x0 => x0.displayName,
      _1846: x0 => x0.enrollmentTime,
      _1847: x0 => x0.factorId,
      _1848: x0 => x0.uid,
      _1850: x0 => x0.hints,
      _1851: x0 => x0.session,
      _1853: x0 => x0.phoneNumber,
      _1863: x0 => ({displayName: x0}),
      _1864: x0 => ({photoURL: x0}),
      _1865: (x0,x1) => x0.getItem(x1),
      _1869: (x0,x1) => x0.getElementById(x1),
      _1870: (x0,x1) => x0.appendChild(x1),
      _1872: (x0,x1) => x0.removeItem(x1),
      _1873: (x0,x1,x2) => x0.setItem(x1,x2),
      _1887: () => globalThis.firebase_core.getApps(),
      _1888: (x0,x1,x2,x3,x4,x5,x6,x7) => ({apiKey: x0,authDomain: x1,databaseURL: x2,projectId: x3,storageBucket: x4,messagingSenderId: x5,measurementId: x6,appId: x7}),
      _1889: (x0,x1) => globalThis.firebase_core.initializeApp(x0,x1),
      _1890: x0 => globalThis.firebase_core.getApp(x0),
      _1891: () => globalThis.firebase_core.getApp(),
      _2012: () => globalThis.firebase_core.SDK_VERSION,
      _2018: x0 => x0.apiKey,
      _2020: x0 => x0.authDomain,
      _2022: x0 => x0.databaseURL,
      _2024: x0 => x0.projectId,
      _2026: x0 => x0.storageBucket,
      _2028: x0 => x0.messagingSenderId,
      _2030: x0 => x0.measurementId,
      _2032: x0 => x0.appId,
      _2034: x0 => x0.name,
      _2035: x0 => x0.options,
      _2038: (x0,x1) => x0.debug(x1),
      _2039: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2039(f,arguments.length,x0) }),
      _2040: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._2040(f,arguments.length,x0,x1) }),
      _2041: (x0,x1) => ({createScript: x0,createScriptURL: x1}),
      _2042: (x0,x1) => x0.createScriptURL(x1),
      _2043: (x0,x1,x2) => x0.createScript(x1,x2),
      _2044: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2044(f,arguments.length,x0) }),
      _2045: () => globalThis.removeSplashFromWeb(),
      _2047: Date.now,
      _2048: secondsSinceEpoch => {
        const date = new Date(secondsSinceEpoch * 1000);
        const match = /\((.*)\)/.exec(date.toString());
        if (match == null) {
            // This should never happen on any recent browser.
            return '';
        }
        return match[1];
      },
      _2049: s => new Date(s * 1000).getTimezoneOffset() * 60,
      _2050: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      _2051: () => {
        let stackString = new Error().stack.toString();
        let frames = stackString.split('\n');
        let drop = 2;
        if (frames[0] === 'Error') {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      _2052: () => typeof dartUseDateNowForTicks !== "undefined",
      _2053: () => 1000 * performance.now(),
      _2054: () => Date.now(),
      _2055: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      _2056: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      _2057: () => new WeakMap(),
      _2058: (map, o) => map.get(o),
      _2059: (map, o, v) => map.set(o, v),
      _2060: x0 => new WeakRef(x0),
      _2061: x0 => x0.deref(),
      _2062: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2062(f,arguments.length,x0) }),
      _2063: x0 => new FinalizationRegistry(x0),
      _2065: (x0,x1,x2) => x0.register(x1,x2),
      _2068: () => globalThis.WeakRef,
      _2069: () => globalThis.FinalizationRegistry,
      _2071: s => JSON.stringify(s),
      _2072: s => printToConsole(s),
      _2073: (o, p, r) => o.replaceAll(p, () => r),
      _2074: (o, p, r) => o.replace(p, () => r),
      _2075: Function.prototype.call.bind(String.prototype.toLowerCase),
      _2076: s => s.toUpperCase(),
      _2077: s => s.trim(),
      _2078: s => s.trimLeft(),
      _2079: s => s.trimRight(),
      _2080: (string, times) => string.repeat(times),
      _2081: Function.prototype.call.bind(String.prototype.indexOf),
      _2082: (s, p, i) => s.lastIndexOf(p, i),
      _2083: (string, token) => string.split(token),
      _2084: Object.is,
      _2085: o => o instanceof Array,
      _2086: (a, i) => a.push(i),
      _2089: (a, l) => a.length = l,
      _2090: a => a.pop(),
      _2091: (a, i) => a.splice(i, 1),
      _2092: (a, s) => a.join(s),
      _2093: (a, s, e) => a.slice(s, e),
      _2094: (a, s, e) => a.splice(s, e),
      _2095: (a, b) => a == b ? 0 : (a > b ? 1 : -1),
      _2096: a => a.length,
      _2097: (a, l) => a.length = l,
      _2098: (a, i) => a[i],
      _2099: (a, i, v) => a[i] = v,
      _2100: (a, t) => a.concat(t),
      _2101: o => {
        if (o instanceof ArrayBuffer) return 0;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 1;
        }
        return 2;
      },
      _2102: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      _2104: o => o instanceof Uint8Array,
      _2105: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      _2106: o => o instanceof Int8Array,
      _2107: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      _2108: o => o instanceof Uint8ClampedArray,
      _2109: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      _2110: o => o instanceof Uint16Array,
      _2111: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      _2112: o => o instanceof Int16Array,
      _2113: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      _2114: o => o instanceof Uint32Array,
      _2115: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      _2116: o => o instanceof Int32Array,
      _2117: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      _2119: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      _2120: o => o instanceof Float32Array,
      _2121: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      _2122: o => o instanceof Float64Array,
      _2123: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      _2124: (t, s) => t.set(s),
      _2125: l => new DataView(new ArrayBuffer(l)),
      _2126: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      _2128: o => o.buffer,
      _2129: o => o.byteOffset,
      _2130: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      _2131: (b, o) => new DataView(b, o),
      _2132: (b, o, l) => new DataView(b, o, l),
      _2133: Function.prototype.call.bind(DataView.prototype.getUint8),
      _2134: Function.prototype.call.bind(DataView.prototype.setUint8),
      _2135: Function.prototype.call.bind(DataView.prototype.getInt8),
      _2136: Function.prototype.call.bind(DataView.prototype.setInt8),
      _2137: Function.prototype.call.bind(DataView.prototype.getUint16),
      _2138: Function.prototype.call.bind(DataView.prototype.setUint16),
      _2139: Function.prototype.call.bind(DataView.prototype.getInt16),
      _2140: Function.prototype.call.bind(DataView.prototype.setInt16),
      _2141: Function.prototype.call.bind(DataView.prototype.getUint32),
      _2142: Function.prototype.call.bind(DataView.prototype.setUint32),
      _2143: Function.prototype.call.bind(DataView.prototype.getInt32),
      _2144: Function.prototype.call.bind(DataView.prototype.setInt32),
      _2147: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      _2148: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      _2149: Function.prototype.call.bind(DataView.prototype.getFloat32),
      _2150: Function.prototype.call.bind(DataView.prototype.setFloat32),
      _2151: Function.prototype.call.bind(DataView.prototype.getFloat64),
      _2152: Function.prototype.call.bind(DataView.prototype.setFloat64),
      _2165: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      _2166: (handle) => clearTimeout(handle),
      _2167: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      _2168: (handle) => clearInterval(handle),
      _2169: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      _2170: () => Date.now(),
      _2175: o => Object.keys(o),
      _2176: x0 => x0.deviceMemory,
      _2177: (x0,x1) => x0.append(x1),
      _2178: x0 => ({xhrSetup: x0}),
      _2179: x0 => new Hls(x0),
      _2180: () => globalThis.Hls.isSupported(),
      _2182: (x0,x1) => x0.loadSource(x1),
      _2183: (x0,x1) => x0.attachMedia(x1),
      _2184: (x0,x1) => x0.item(x1),
      _2188: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      _2190: (x0,x1) => x0.canPlayType(x1),
      _2193: () => new XMLHttpRequest(),
      _2194: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _2195: x0 => x0.send(),
      _2197: () => new FileReader(),
      _2198: (x0,x1) => x0.readAsArrayBuffer(x1),
      _2199: () => new AbortController(),
      _2200: x0 => x0.abort(),
      _2201: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      _2202: (x0,x1) => globalThis.fetch(x0,x1),
      _2203: (x0,x1) => x0.get(x1),
      _2204: f => finalizeWrapper(f, function(x0,x1,x2) { return dartInstance.exports._2204(f,arguments.length,x0,x1,x2) }),
      _2205: (x0,x1) => x0.forEach(x1),
      _2206: x0 => x0.getReader(),
      _2207: x0 => x0.read(),
      _2208: x0 => x0.cancel(),
      _2210: (x0,x1) => x0.send(x1),
      _2212: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2212(f,arguments.length,x0) }),
      _2213: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2213(f,arguments.length,x0) }),
      _2218: (x0,x1) => x0.matchMedia(x1),
      _2228: () => globalThis.window.flutter_inappwebview,
      _2232: (x0,x1) => { x0.nativeCommunication = x1 },
      _2233: (x0,x1) => x0.key(x1),
      _2234: (x0,x1) => x0.item(x1),
      _2235: x0 => x0.trustedTypes,
      _2236: (x0,x1) => { x0.text = x1 },
      _2244: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      _2245: (x0,x1) => x0.exec(x1),
      _2246: (x0,x1) => x0.test(x1),
      _2247: x0 => x0.pop(),
      _2249: o => o === undefined,
      _2251: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      _2253: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      _2254: o => o instanceof RegExp,
      _2255: (l, r) => l === r,
      _2256: o => o,
      _2257: o => o,
      _2258: o => o,
      _2259: b => !!b,
      _2260: o => o.length,
      _2262: (o, i) => o[i],
      _2263: f => f.dartFunction,
      _2264: () => ({}),
      _2265: () => [],
      _2267: () => globalThis,
      _2268: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      _2269: (o, p) => p in o,
      _2270: (o, p) => o[p],
      _2271: (o, p, v) => o[p] = v,
      _2272: (o, m, a) => o[m].apply(o, a),
      _2274: o => String(o),
      _2275: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      _2276: o => {
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
      _2277: o => [o],
      _2278: (o0, o1) => [o0, o1],
      _2279: (o0, o1, o2) => [o0, o1, o2],
      _2280: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      _2281: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2282: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2283: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2284: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2285: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2286: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2287: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2288: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2289: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2290: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2291: x0 => new ArrayBuffer(x0),
      _2292: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      _2293: x0 => x0.input,
      _2294: x0 => x0.index,
      _2295: x0 => x0.groups,
      _2296: x0 => x0.flags,
      _2297: x0 => x0.multiline,
      _2298: x0 => x0.ignoreCase,
      _2299: x0 => x0.unicode,
      _2300: x0 => x0.dotAll,
      _2301: (x0,x1) => { x0.lastIndex = x1 },
      _2302: (o, p) => p in o,
      _2303: (o, p) => o[p],
      _2304: (o, p, v) => o[p] = v,
      _2305: (o, p) => delete o[p],
      _2306: x0 => x0.random(),
      _2307: (x0,x1) => x0.getRandomValues(x1),
      _2308: () => globalThis.crypto,
      _2309: () => globalThis.Math,
      _2310: Function.prototype.call.bind(Number.prototype.toString),
      _2311: Function.prototype.call.bind(BigInt.prototype.toString),
      _2312: Function.prototype.call.bind(Number.prototype.toString),
      _2313: (d, digits) => d.toFixed(digits),
      _2317: () => globalThis.document,
      _2323: (x0,x1) => { x0.height = x1 },
      _2325: (x0,x1) => { x0.width = x1 },
      _2334: x0 => x0.style,
      _2337: x0 => x0.src,
      _2338: (x0,x1) => { x0.src = x1 },
      _2339: x0 => x0.naturalWidth,
      _2340: x0 => x0.naturalHeight,
      _2356: x0 => x0.status,
      _2357: (x0,x1) => { x0.responseType = x1 },
      _2359: x0 => x0.response,
      _2404: x0 => x0.status,
      _2407: (x0,x1) => { x0.responseType = x1 },
      _2408: x0 => x0.response,
      _2409: x0 => x0.responseText,
      _2484: x0 => x0.style,
      _2497: (x0,x1) => { x0.oncancel = x1 },
      _2503: (x0,x1) => { x0.onchange = x1 },
      _2543: (x0,x1) => { x0.onerror = x1 },
      _2960: x0 => x0.src,
      _2961: (x0,x1) => { x0.src = x1 },
      _2964: x0 => x0.name,
      _2965: (x0,x1) => { x0.name = x1 },
      _2966: x0 => x0.sandbox,
      _2967: x0 => x0.allow,
      _2968: (x0,x1) => { x0.allow = x1 },
      _2969: x0 => x0.allowFullscreen,
      _2970: (x0,x1) => { x0.allowFullscreen = x1 },
      _2975: x0 => x0.referrerPolicy,
      _2976: (x0,x1) => { x0.referrerPolicy = x1 },
      _3056: x0 => x0.videoWidth,
      _3057: x0 => x0.videoHeight,
      _3086: x0 => x0.error,
      _3088: (x0,x1) => { x0.src = x1 },
      _3097: x0 => x0.buffered,
      _3100: x0 => x0.currentTime,
      _3101: (x0,x1) => { x0.currentTime = x1 },
      _3102: x0 => x0.duration,
      _3103: x0 => x0.paused,
      _3106: x0 => x0.playbackRate,
      _3118: (x0,x1) => { x0.controls = x1 },
      _3119: x0 => x0.volume,
      _3120: (x0,x1) => { x0.volume = x1 },
      _3121: x0 => x0.muted,
      _3122: (x0,x1) => { x0.muted = x1 },
      _3138: x0 => x0.message,
      _3211: x0 => x0.length,
      _3407: (x0,x1) => { x0.accept = x1 },
      _3421: x0 => x0.files,
      _3447: (x0,x1) => { x0.multiple = x1 },
      _3465: (x0,x1) => { x0.type = x1 },
      _3714: x0 => x0.src,
      _3715: (x0,x1) => { x0.src = x1 },
      _3717: (x0,x1) => { x0.type = x1 },
      _3721: (x0,x1) => { x0.async = x1 },
      _3725: (x0,x1) => { x0.crossOrigin = x1 },
      _3727: (x0,x1) => { x0.text = x1 },
      _3729: (x0,x1) => { x0.integrity = x1 },
      _3735: (x0,x1) => { x0.charset = x1 },
      _4183: () => globalThis.window,
      _4222: x0 => x0.document,
      _4225: x0 => x0.location,
      _4244: x0 => x0.navigator,
      _4248: x0 => x0.screen,
      _4260: x0 => x0.devicePixelRatio,
      _4506: x0 => x0.trustedTypes,
      _4507: x0 => x0.sessionStorage,
      _4508: x0 => x0.localStorage,
      _4518: x0 => x0.origin,
      _4523: x0 => x0.hostname,
      _4527: x0 => x0.pathname,
      _4614: x0 => x0.geolocation,
      _4617: x0 => x0.mediaDevices,
      _4619: x0 => x0.permissions,
      _4630: x0 => x0.platform,
      _4633: x0 => x0.userAgent,
      _4634: x0 => x0.vendor,
      _4639: x0 => x0.onLine,
      _4841: x0 => x0.length,
      _6745: x0 => x0.type,
      _6746: x0 => x0.target,
      _6786: x0 => x0.signal,
      _6795: x0 => x0.length,
      _6797: x0 => x0.length,
      _6838: x0 => x0.baseURI,
      _6844: x0 => x0.firstChild,
      _6855: () => globalThis.document,
      _6912: x0 => x0.documentElement,
      _6933: x0 => x0.body,
      _6935: x0 => x0.head,
      _7263: x0 => x0.id,
      _7264: (x0,x1) => { x0.id = x1 },
      _7288: (x0,x1) => { x0.innerHTML = x1 },
      _7291: x0 => x0.children,
      _7494: x0 => x0.length,
      _8609: x0 => x0.value,
      _8611: x0 => x0.done,
      _8791: x0 => x0.size,
      _8792: x0 => x0.type,
      _8799: x0 => x0.name,
      _8800: x0 => x0.lastModified,
      _8805: x0 => x0.length,
      _8811: x0 => x0.result,
      _9308: x0 => x0.url,
      _9310: x0 => x0.status,
      _9312: x0 => x0.statusText,
      _9313: x0 => x0.headers,
      _9314: x0 => x0.body,
      _9581: x0 => x0.type,
      _9596: x0 => x0.matches,
      _9607: x0 => x0.availWidth,
      _9608: x0 => x0.availHeight,
      _9613: x0 => x0.orientation,
      _11437: (x0,x1) => { x0.border = x1 },
      _11715: (x0,x1) => { x0.display = x1 },
      _11879: (x0,x1) => { x0.height = x1 },
      _12569: (x0,x1) => { x0.width = x1 },
      _12937: x0 => x0.name,
      _12938: x0 => x0.message,
      _13652: () => globalThis.console,
      _13678: () => globalThis.window.flutterCanvasKit,
      _13679: () => globalThis.window._flutter_skwasmInstance,
      _13680: x0 => x0.name,
      _13681: x0 => x0.message,
      _13682: x0 => x0.code,
      _13684: x0 => x0.customData,
      _13685: () => globalThis.removeSplashFromWeb(),

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
