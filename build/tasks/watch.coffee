module.exports = ->

  @loadNpmTasks "grunt-contrib-watch"

  @config "watch",
    options:
      spawn: false
    grunt:
      files: "Gruntfile.coffee"
      tasks: ["development"]
    coffee:
      files: "src/**/*.coffee"
      tasks: ["coffee"]
