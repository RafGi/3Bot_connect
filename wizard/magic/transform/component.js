define(['babel-standalone', 'http-vue-loader', 'sassjs'], function (Babel, httpVueLoader, Sass) {
  return {
    load: function (name, req, onload, config) {
      httpVueLoader(`src/components/${name}/index.vue`, name)().then(onload)
    }
  }
})
