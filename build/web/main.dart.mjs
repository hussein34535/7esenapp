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
      _1316: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _1317: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      _1318: (x0,x1) => x0.createElement(x1),
      _1323: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1328: x0 => globalThis.URL.createObjectURL(x0),
      _1331: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1331(f,arguments.length,x0) }),
      _1332: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1332(f,arguments.length,x0) }),
      _1333: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1333(f,arguments.length,x0) }),
      _1334: (x0,x1) => x0.querySelector(x1),
      _1335: (x0,x1) => x0.replaceChildren(x1),
      _1336: x0 => x0.click(),
      _1343: x0 => x0.toArray(),
      _1344: x0 => x0.toUint8Array(),
      _1345: x0 => ({serverTimestamps: x0}),
      _1346: x0 => ({source: x0}),
      _1347: x0 => ({merge: x0}),
      _1349: x0 => new firebase_firestore.FieldPath(x0),
      _1350: (x0,x1) => new firebase_firestore.FieldPath(x0,x1),
      _1351: (x0,x1,x2) => new firebase_firestore.FieldPath(x0,x1,x2),
      _1352: (x0,x1,x2,x3) => new firebase_firestore.FieldPath(x0,x1,x2,x3),
      _1353: (x0,x1,x2,x3,x4) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4),
      _1354: (x0,x1,x2,x3,x4,x5) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5),
      _1355: (x0,x1,x2,x3,x4,x5,x6) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6),
      _1356: (x0,x1,x2,x3,x4,x5,x6,x7) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7),
      _1357: (x0,x1,x2,x3,x4,x5,x6,x7,x8) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8),
      _1358: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8,x9),
      _1359: () => globalThis.firebase_firestore.documentId(),
      _1360: (x0,x1) => new firebase_firestore.GeoPoint(x0,x1),
      _1361: x0 => globalThis.firebase_firestore.vector(x0),
      _1362: x0 => globalThis.firebase_firestore.Bytes.fromUint8Array(x0),
      _1364: (x0,x1) => globalThis.firebase_firestore.collection(x0,x1),
      _1366: (x0,x1) => globalThis.firebase_firestore.doc(x0,x1),
      _1369: x0 => x0.call(),
      _1399: x0 => globalThis.firebase_firestore.getDoc(x0),
      _1400: x0 => globalThis.firebase_firestore.getDocFromServer(x0),
      _1401: x0 => globalThis.firebase_firestore.getDocFromCache(x0),
      _1402: (x0,x1) => ({includeMetadataChanges: x0,source: x1}),
      _1403: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1403(f,arguments.length,x0) }),
      _1404: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1404(f,arguments.length,x0) }),
      _1405: (x0,x1,x2,x3) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2,x3),
      _1406: (x0,x1,x2) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2),
      _1407: (x0,x1,x2) => globalThis.firebase_firestore.setDoc(x0,x1,x2),
      _1408: (x0,x1) => globalThis.firebase_firestore.setDoc(x0,x1),
      _1425: (x0,x1) => x0.data(x1),
      _1438: () => globalThis.firebase_firestore.serverTimestamp(),
      _1446: (x0,x1) => globalThis.firebase_firestore.getFirestore(x0,x1),
      _1448: x0 => globalThis.firebase_firestore.Timestamp.fromMillis(x0),
      _1449: f => finalizeWrapper(f, function() { return dartInstance.exports._1449(f,arguments.length) }),
      _1466: () => globalThis.firebase_firestore.updateDoc,
      _1473: x0 => x0.path,
      _1476: () => globalThis.firebase_firestore.GeoPoint,
      _1477: x0 => x0.latitude,
      _1478: x0 => x0.longitude,
      _1480: () => globalThis.firebase_firestore.VectorValue,
      _1481: () => globalThis.firebase_firestore.Bytes,
      _1492: () => globalThis.firebase_firestore.DocumentReference,
      _1496: x0 => x0.path,
      _1505: x0 => x0.metadata,
      _1506: x0 => x0.ref,
      _1517: () => globalThis.firebase_firestore.Timestamp,
      _1518: x0 => x0.seconds,
      _1519: x0 => x0.nanoseconds,
      _1555: x0 => x0.hasPendingWrites,
      _1557: x0 => x0.fromCache,
      _1564: x0 => x0.source,
      _1576: x0 => x0.load(),
      _1577: x0 => x0.play(),
      _1578: x0 => x0.pause(),
      _1583: (x0,x1) => x0.end(x1),
      _1584: x0 => x0.decode(),
      _1585: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1586: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      _1587: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1587(f,arguments.length,x0) }),
      _1588: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1588(f,arguments.length,x0) }),
      _1589: x0 => x0.send(),
      _1590: () => new XMLHttpRequest(),
      _1591: x0 => globalThis.Wakelock.toggle(x0),
      _1602: (x0,x1) => x0.getIdToken(x1),
      _1611: x0 => x0.reload(),
      _1618: (x0,x1) => globalThis.firebase_auth.updateProfile(x0,x1),
      _1621: x0 => x0.toJSON(),
      _1622: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1622(f,arguments.length,x0) }),
      _1623: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1623(f,arguments.length,x0) }),
      _1624: (x0,x1,x2) => x0.onAuthStateChanged(x1,x2),
      _1625: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1625(f,arguments.length,x0) }),
      _1626: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1626(f,arguments.length,x0) }),
      _1627: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1627(f,arguments.length,x0) }),
      _1628: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1628(f,arguments.length,x0) }),
      _1629: (x0,x1,x2) => x0.onIdTokenChanged(x1,x2),
      _1633: (x0,x1,x2) => globalThis.firebase_auth.createUserWithEmailAndPassword(x0,x1,x2),
      _1643: (x0,x1,x2) => globalThis.firebase_auth.signInWithEmailAndPassword(x0,x1,x2),
      _1648: x0 => x0.signOut(),
      _1649: (x0,x1) => globalThis.firebase_auth.connectAuthEmulator(x0,x1),
      _1672: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromResult(x0),
      _1687: x0 => globalThis.firebase_auth.getAdditionalUserInfo(x0),
      _1688: (x0,x1,x2) => ({errorMap: x0,persistence: x1,popupRedirectResolver: x2}),
      _1689: (x0,x1) => globalThis.firebase_auth.initializeAuth(x0,x1),
      _1695: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromError(x0),
      _1698: (x0,x1) => ({displayName: x0,photoURL: x1}),
      _1710: () => globalThis.firebase_auth.debugErrorMap,
      _1713: () => globalThis.firebase_auth.browserSessionPersistence,
      _1715: () => globalThis.firebase_auth.browserLocalPersistence,
      _1717: () => globalThis.firebase_auth.indexedDBLocalPersistence,
      _1720: x0 => globalThis.firebase_auth.multiFactor(x0),
      _1721: (x0,x1) => globalThis.firebase_auth.getMultiFactorResolver(x0,x1),
      _1723: x0 => x0.currentUser,
      _1727: x0 => x0.tenantId,
      _1737: x0 => x0.displayName,
      _1738: x0 => x0.email,
      _1739: x0 => x0.phoneNumber,
      _1740: x0 => x0.photoURL,
      _1741: x0 => x0.providerId,
      _1742: x0 => x0.uid,
      _1743: x0 => x0.emailVerified,
      _1744: x0 => x0.isAnonymous,
      _1745: x0 => x0.providerData,
      _1746: x0 => x0.refreshToken,
      _1747: x0 => x0.tenantId,
      _1748: x0 => x0.metadata,
      _1750: x0 => x0.providerId,
      _1751: x0 => x0.signInMethod,
      _1752: x0 => x0.accessToken,
      _1753: x0 => x0.idToken,
      _1754: x0 => x0.secret,
      _1765: x0 => x0.creationTime,
      _1766: x0 => x0.lastSignInTime,
      _1771: x0 => x0.code,
      _1773: x0 => x0.message,
      _1785: x0 => x0.email,
      _1786: x0 => x0.phoneNumber,
      _1787: x0 => x0.tenantId,
      _1810: x0 => x0.user,
      _1813: x0 => x0.providerId,
      _1814: x0 => x0.profile,
      _1815: x0 => x0.username,
      _1816: x0 => x0.isNewUser,
      _1819: () => globalThis.firebase_auth.browserPopupRedirectResolver,
      _1824: x0 => x0.displayName,
      _1825: x0 => x0.enrollmentTime,
      _1826: x0 => x0.factorId,
      _1827: x0 => x0.uid,
      _1829: x0 => x0.hints,
      _1830: x0 => x0.session,
      _1832: x0 => x0.phoneNumber,
      _1842: x0 => ({displayName: x0}),
      _1843: x0 => ({photoURL: x0}),
      _1844: (x0,x1) => x0.getItem(x1),
      _1848: (x0,x1) => x0.getElementById(x1),
      _1849: (x0,x1) => x0.appendChild(x1),
      _1851: (x0,x1) => x0.removeItem(x1),
      _1852: (x0,x1,x2) => x0.setItem(x1,x2),
      _1866: () => globalThis.firebase_core.getApps(),
      _1867: (x0,x1,x2,x3,x4,x5,x6,x7) => ({apiKey: x0,authDomain: x1,databaseURL: x2,projectId: x3,storageBucket: x4,messagingSenderId: x5,measurementId: x6,appId: x7}),
      _1868: (x0,x1) => globalThis.firebase_core.initializeApp(x0,x1),
      _1869: x0 => globalThis.firebase_core.getApp(x0),
      _1870: () => globalThis.firebase_core.getApp(),
      _1991: () => globalThis.firebase_core.SDK_VERSION,
      _1997: x0 => x0.apiKey,
      _1999: x0 => x0.authDomain,
      _2001: x0 => x0.databaseURL,
      _2003: x0 => x0.projectId,
      _2005: x0 => x0.storageBucket,
      _2007: x0 => x0.messagingSenderId,
      _2009: x0 => x0.measurementId,
      _2011: x0 => x0.appId,
      _2013: x0 => x0.name,
      _2014: x0 => x0.options,
      _2017: (x0,x1) => x0.debug(x1),
      _2018: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2018(f,arguments.length,x0) }),
      _2019: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._2019(f,arguments.length,x0,x1) }),
      _2020: (x0,x1) => ({createScript: x0,createScriptURL: x1}),
      _2021: (x0,x1,x2) => x0.createPolicy(x1,x2),
      _2022: (x0,x1) => x0.createScriptURL(x1),
      _2023: (x0,x1,x2) => x0.createScript(x1,x2),
      _2024: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2024(f,arguments.length,x0) }),
      _2025: () => globalThis.removeSplashFromWeb(),
      _2027: Date.now,
      _2029: s => new Date(s * 1000).getTimezoneOffset() * 60,
      _2030: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      _2031: () => {
        let stackString = new Error().stack.toString();
        let frames = stackString.split('\n');
        let drop = 2;
        if (frames[0] === 'Error') {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      _2032: () => typeof dartUseDateNowForTicks !== "undefined",
      _2033: () => 1000 * performance.now(),
      _2034: () => Date.now(),
      _2035: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      _2036: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      _2037: () => new WeakMap(),
      _2038: (map, o) => map.get(o),
      _2039: (map, o, v) => map.set(o, v),
      _2040: x0 => new WeakRef(x0),
      _2041: x0 => x0.deref(),
      _2042: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2042(f,arguments.length,x0) }),
      _2043: x0 => new FinalizationRegistry(x0),
      _2045: (x0,x1,x2) => x0.register(x1,x2),
      _2048: () => globalThis.WeakRef,
      _2049: () => globalThis.FinalizationRegistry,
      _2051: s => JSON.stringify(s),
      _2052: s => printToConsole(s),
      _2053: (o, p, r) => o.replaceAll(p, () => r),
      _2054: (o, p, r) => o.replace(p, () => r),
      _2055: Function.prototype.call.bind(String.prototype.toLowerCase),
      _2056: s => s.toUpperCase(),
      _2057: s => s.trim(),
      _2058: s => s.trimLeft(),
      _2059: s => s.trimRight(),
      _2060: (string, times) => string.repeat(times),
      _2061: Function.prototype.call.bind(String.prototype.indexOf),
      _2062: (s, p, i) => s.lastIndexOf(p, i),
      _2063: (string, token) => string.split(token),
      _2064: Object.is,
      _2065: o => o instanceof Array,
      _2066: (a, i) => a.push(i),
      _2069: (a, l) => a.length = l,
      _2070: a => a.pop(),
      _2071: (a, i) => a.splice(i, 1),
      _2072: (a, s) => a.join(s),
      _2073: (a, s, e) => a.slice(s, e),
      _2074: (a, s, e) => a.splice(s, e),
      _2075: (a, b) => a == b ? 0 : (a > b ? 1 : -1),
      _2076: a => a.length,
      _2077: (a, l) => a.length = l,
      _2078: (a, i) => a[i],
      _2079: (a, i, v) => a[i] = v,
      _2080: (a, t) => a.concat(t),
      _2081: o => {
        if (o instanceof ArrayBuffer) return 0;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 1;
        }
        return 2;
      },
      _2082: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      _2084: o => o instanceof Uint8Array,
      _2085: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      _2086: o => o instanceof Int8Array,
      _2087: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      _2088: o => o instanceof Uint8ClampedArray,
      _2089: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      _2090: o => o instanceof Uint16Array,
      _2091: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      _2092: o => o instanceof Int16Array,
      _2093: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      _2094: o => o instanceof Uint32Array,
      _2095: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      _2096: o => o instanceof Int32Array,
      _2097: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      _2099: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      _2100: o => o instanceof Float32Array,
      _2101: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      _2102: o => o instanceof Float64Array,
      _2103: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      _2104: (t, s) => t.set(s),
      _2105: l => new DataView(new ArrayBuffer(l)),
      _2106: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      _2108: o => o.buffer,
      _2109: o => o.byteOffset,
      _2110: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      _2111: (b, o) => new DataView(b, o),
      _2112: (b, o, l) => new DataView(b, o, l),
      _2113: Function.prototype.call.bind(DataView.prototype.getUint8),
      _2114: Function.prototype.call.bind(DataView.prototype.setUint8),
      _2115: Function.prototype.call.bind(DataView.prototype.getInt8),
      _2116: Function.prototype.call.bind(DataView.prototype.setInt8),
      _2117: Function.prototype.call.bind(DataView.prototype.getUint16),
      _2118: Function.prototype.call.bind(DataView.prototype.setUint16),
      _2119: Function.prototype.call.bind(DataView.prototype.getInt16),
      _2120: Function.prototype.call.bind(DataView.prototype.setInt16),
      _2121: Function.prototype.call.bind(DataView.prototype.getUint32),
      _2122: Function.prototype.call.bind(DataView.prototype.setUint32),
      _2123: Function.prototype.call.bind(DataView.prototype.getInt32),
      _2124: Function.prototype.call.bind(DataView.prototype.setInt32),
      _2127: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      _2128: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      _2129: Function.prototype.call.bind(DataView.prototype.getFloat32),
      _2130: Function.prototype.call.bind(DataView.prototype.setFloat32),
      _2131: Function.prototype.call.bind(DataView.prototype.getFloat64),
      _2132: Function.prototype.call.bind(DataView.prototype.setFloat64),
      _2145: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      _2146: (handle) => clearTimeout(handle),
      _2147: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      _2148: (handle) => clearInterval(handle),
      _2149: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      _2150: () => Date.now(),
      _2155: o => Object.keys(o),
      _2156: (x0,x1) => x0.append(x1),
      _2157: x0 => ({xhrSetup: x0}),
      _2158: x0 => new Hls(x0),
      _2159: () => globalThis.Hls.isSupported(),
      _2161: (x0,x1) => x0.loadSource(x1),
      _2162: (x0,x1) => x0.attachMedia(x1),
      _2163: (x0,x1) => x0.item(x1),
      _2167: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      _2169: (x0,x1) => x0.canPlayType(x1),
      _2172: () => new XMLHttpRequest(),
      _2173: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _2174: x0 => x0.send(),
      _2178: () => new AbortController(),
      _2179: x0 => x0.abort(),
      _2180: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      _2181: (x0,x1) => globalThis.fetch(x0,x1),
      _2182: (x0,x1) => x0.get(x1),
      _2183: f => finalizeWrapper(f, function(x0,x1,x2) { return dartInstance.exports._2183(f,arguments.length,x0,x1,x2) }),
      _2184: (x0,x1) => x0.forEach(x1),
      _2185: x0 => x0.getReader(),
      _2186: x0 => x0.read(),
      _2187: x0 => x0.cancel(),
      _2189: (x0,x1) => x0.send(x1),
      _2191: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2191(f,arguments.length,x0) }),
      _2192: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2192(f,arguments.length,x0) }),
      _2206: () => globalThis.window.flutter_inappwebview,
      _2210: (x0,x1) => { x0.nativeCommunication = x1 },
      _2211: (x0,x1) => x0.key(x1),
      _2212: (x0,x1) => x0.item(x1),
      _2213: x0 => x0.trustedTypes,
      _2214: (x0,x1) => { x0.text = x1 },
      _2222: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      _2223: (x0,x1) => x0.exec(x1),
      _2224: (x0,x1) => x0.test(x1),
      _2225: x0 => x0.pop(),
      _2227: o => o === undefined,
      _2229: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      _2231: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      _2232: o => o instanceof RegExp,
      _2233: (l, r) => l === r,
      _2234: o => o,
      _2235: o => o,
      _2236: o => o,
      _2237: b => !!b,
      _2238: o => o.length,
      _2240: (o, i) => o[i],
      _2241: f => f.dartFunction,
      _2242: () => ({}),
      _2243: () => [],
      _2245: () => globalThis,
      _2246: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      _2248: (o, p) => o[p],
      _2249: (o, p, v) => o[p] = v,
      _2250: (o, m, a) => o[m].apply(o, a),
      _2252: o => String(o),
      _2253: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      _2254: o => {
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
      _2255: o => [o],
      _2256: (o0, o1) => [o0, o1],
      _2257: (o0, o1, o2) => [o0, o1, o2],
      _2258: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      _2259: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2260: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2263: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2264: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2265: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2266: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2267: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2268: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2269: x0 => new ArrayBuffer(x0),
      _2270: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      _2271: x0 => x0.input,
      _2272: x0 => x0.index,
      _2274: x0 => x0.flags,
      _2275: x0 => x0.multiline,
      _2276: x0 => x0.ignoreCase,
      _2277: x0 => x0.unicode,
      _2278: x0 => x0.dotAll,
      _2279: (x0,x1) => { x0.lastIndex = x1 },
      _2280: (o, p) => p in o,
      _2281: (o, p) => o[p],
      _2282: (o, p, v) => o[p] = v,
      _2283: (o, p) => delete o[p],
      _2284: x0 => x0.random(),
      _2285: (x0,x1) => x0.getRandomValues(x1),
      _2286: () => globalThis.crypto,
      _2287: () => globalThis.Math,
      _2288: Function.prototype.call.bind(Number.prototype.toString),
      _2289: Function.prototype.call.bind(BigInt.prototype.toString),
      _2290: Function.prototype.call.bind(Number.prototype.toString),
      _2291: (d, digits) => d.toFixed(digits),
      _2295: () => globalThis.document,
      _2301: (x0,x1) => { x0.height = x1 },
      _2303: (x0,x1) => { x0.width = x1 },
      _2312: x0 => x0.style,
      _2315: x0 => x0.src,
      _2316: (x0,x1) => { x0.src = x1 },
      _2317: x0 => x0.naturalWidth,
      _2318: x0 => x0.naturalHeight,
      _2334: x0 => x0.status,
      _2335: (x0,x1) => { x0.responseType = x1 },
      _2337: x0 => x0.response,
      _2382: x0 => x0.status,
      _2385: (x0,x1) => { x0.responseType = x1 },
      _2386: x0 => x0.response,
      _2387: x0 => x0.responseText,
      _2462: x0 => x0.style,
      _2475: (x0,x1) => { x0.oncancel = x1 },
      _2481: (x0,x1) => { x0.onchange = x1 },
      _2521: (x0,x1) => { x0.onerror = x1 },
      _2938: x0 => x0.src,
      _2939: (x0,x1) => { x0.src = x1 },
      _2942: x0 => x0.name,
      _2943: (x0,x1) => { x0.name = x1 },
      _2944: x0 => x0.sandbox,
      _2945: x0 => x0.allow,
      _2946: (x0,x1) => { x0.allow = x1 },
      _2947: x0 => x0.allowFullscreen,
      _2948: (x0,x1) => { x0.allowFullscreen = x1 },
      _2953: x0 => x0.referrerPolicy,
      _2954: (x0,x1) => { x0.referrerPolicy = x1 },
      _3034: x0 => x0.videoWidth,
      _3035: x0 => x0.videoHeight,
      _3064: x0 => x0.error,
      _3066: (x0,x1) => { x0.src = x1 },
      _3075: x0 => x0.buffered,
      _3078: x0 => x0.currentTime,
      _3079: (x0,x1) => { x0.currentTime = x1 },
      _3080: x0 => x0.duration,
      _3081: x0 => x0.paused,
      _3084: x0 => x0.playbackRate,
      _3096: (x0,x1) => { x0.controls = x1 },
      _3097: x0 => x0.volume,
      _3098: (x0,x1) => { x0.volume = x1 },
      _3099: x0 => x0.muted,
      _3100: (x0,x1) => { x0.muted = x1 },
      _3116: x0 => x0.message,
      _3189: x0 => x0.length,
      _3385: (x0,x1) => { x0.accept = x1 },
      _3399: x0 => x0.files,
      _3425: (x0,x1) => { x0.multiple = x1 },
      _3443: (x0,x1) => { x0.type = x1 },
      _3692: x0 => x0.src,
      _3693: (x0,x1) => { x0.src = x1 },
      _3695: (x0,x1) => { x0.type = x1 },
      _3699: (x0,x1) => { x0.async = x1 },
      _3703: (x0,x1) => { x0.crossOrigin = x1 },
      _3705: (x0,x1) => { x0.text = x1 },
      _3713: (x0,x1) => { x0.charset = x1 },
      _4161: () => globalThis.window,
      _4201: x0 => x0.document,
      _4204: x0 => x0.location,
      _4223: x0 => x0.navigator,
      _4485: x0 => x0.trustedTypes,
      _4486: x0 => x0.sessionStorage,
      _4487: x0 => x0.localStorage,
      _4502: x0 => x0.hostname,
      _4593: x0 => x0.geolocation,
      _4596: x0 => x0.mediaDevices,
      _4598: x0 => x0.permissions,
      _4612: x0 => x0.userAgent,
      _4613: x0 => x0.vendor,
      _4820: x0 => x0.length,
      _6724: x0 => x0.type,
      _6725: x0 => x0.target,
      _6765: x0 => x0.signal,
      _6777: x0 => x0.length,
      _6837: () => globalThis.document,
      _6895: x0 => x0.documentElement,
      _6916: x0 => x0.body,
      _6918: x0 => x0.head,
      _7246: x0 => x0.id,
      _7247: (x0,x1) => { x0.id = x1 },
      _7271: (x0,x1) => { x0.innerHTML = x1 },
      _7274: x0 => x0.children,
      _7477: x0 => x0.length,
      _8592: x0 => x0.value,
      _8594: x0 => x0.done,
      _8774: x0 => x0.size,
      _8775: x0 => x0.type,
      _8782: x0 => x0.name,
      _8783: x0 => x0.lastModified,
      _8788: x0 => x0.length,
      _9291: x0 => x0.url,
      _9293: x0 => x0.status,
      _9295: x0 => x0.statusText,
      _9296: x0 => x0.headers,
      _9297: x0 => x0.body,
      _11420: (x0,x1) => { x0.border = x1 },
      _11698: (x0,x1) => { x0.display = x1 },
      _11862: (x0,x1) => { x0.height = x1 },
      _12552: (x0,x1) => { x0.width = x1 },
      _12920: x0 => x0.name,
      _12921: x0 => x0.message,
      _13636: () => globalThis.console,
      _13664: x0 => x0.name,
      _13665: x0 => x0.message,
      _13666: x0 => x0.code,
      _13668: x0 => x0.customData,
      _13669: () => globalThis.removeSplashFromWeb(),

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
