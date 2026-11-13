pragma Singleton
import QtQuick

QtObject {
  // Every argv handed to execDetached, so a test can see what would launch.
  property var detached: []
  function env(name) { return "" }
  function execDetached(command) { detached = detached.concat([command]) }
}
