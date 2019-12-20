define(['babel-standalone', 'http-vue-loader', 'sassjs'], function (Babel, httpVueLoader, Sass) {
  httpVueLoader.scriptExportsHandler = function (script) {
    return new Promise(function (resolve) {
      require([ this.component.name ], function (component) {
        resolve(component.default)
      })
    }.bind(this))
  }

  httpVueLoader.langProcessor.babel = function (script) {
    return Babel.transform(script, {
      moduleId: this.name,
      presets: [
        'es2015',
        'stage-3'
      ],
      plugins: [
        'transform-es2015-modules-amd'
      ]
    }).code
  }
  httpVueLoader.langProcessor.scss = function (scssText) {
    Sass.setWorkerUrl('magic/sass/sass.worker.js')
    var sass = new Sass()
    return new Promise(function (resolve, reject) {
      sass.compile(scssText, function (result) {
        if (result.status === 0) { resolve(result.text) } else { reject(result) }
      })
    })
  }

  return {
    load: function (name, req, onload, config) {
      httpVueLoader(`src/views/${name}/index.vue`, name)().then(onload)
    }
  }
})
