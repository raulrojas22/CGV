/* lazy_jszip.js — Carga JSZip bajo demanda solo cuando se necesita exportar SVG.
   Retorna una Promise que se resuelve con la librería JSZip. */
(function() {
  'use strict';

  var jszipPromise = null;

  function loadJSZip() {
    if (jszipPromise) return jszipPromise;

    if (window.JSZip) {
      jszipPromise = Promise.resolve(window.JSZip);
      return jszipPromise;
    }

    jszipPromise = new Promise(function(resolve, reject) {
      var script = document.createElement('script');
      script.src = 'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js';
      script.async = true;
      script.onload = function() {
        if (window.JSZip) {
          resolve(window.JSZip);
        } else {
          reject(new Error('JSZip loaded but not available on window'));
        }
      };
      script.onerror = function() {
        jszipPromise = null;
        reject(new Error('Failed to load JSZip'));
      };
      document.head.appendChild(script);
    });

    return jszipPromise;
  }

  window.loadJSZip = loadJSZip;
})();
