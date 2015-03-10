module.exports = ->
  # Load task configurations.
  @loadTasks "build/tasks"

  # COMMON
  @registerTask "coffee",["coffeelint"]
  @registerTask "dev",   ["development", "connect", "watch"]
  @registerTask "build", ["coffee"]

  # ENVIRONMENTS
  @registerTask "development",   ["build"]
  @registerTask "preproduction", ["build"]
  @registerTask "production",    ["build"]

  # DEFAULT
  @registerTask "default", ["development"]
  @registerTask "heroku", ["production"]
