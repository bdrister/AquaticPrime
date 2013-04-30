path = require 'path'

module.exports = (grunt) ->
  # load all grunt tasks
  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)

  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    clean:
      dist: ['dist']

    coffee:
      dist:
        expand: true
        src: ['{,*/}*.coffee', '!Gruntfile.coffee']
        dest: 'dist'
        ext: '.js'

    copy:
      dist:
        files: [{
          expand: true
          dest: 'dist'
          src: [ 'LICENSE', 'package.json' ]
        }]

  grunt.registerTask 'dist', ['clean', 'coffee']
  grunt.registerTask 'publish', ['dist', 'copy']
