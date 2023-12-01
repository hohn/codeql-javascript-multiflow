/**
 * @kind path-problem
 */

import javascript
import DataFlow::PathGraph

// Ultimate source
// ----------------
//     var line = stdinBuffer.toString();
// predicate uSource(MethodCallExpr sbts) { sbts.getMethodName().matches("%toString%") }

// Ultimate sink
// ----------------
//     db.exec(query);
// predicate uSink(MethodCallExpr dbe) { dbe.getMethodName().matches("%exec%") }

// Flow sink origin
// ------------------------
// Connect
//     const db = new sqlite3.Database(
// to its use
//     db.exec(query);
//
class FlowSinkOrigin extends DataFlow::FlowLabel {
  FlowSinkOrigin() { this = "FlowSinkOrigin" }
}

class IdentifyFlowSink extends DataFlow::Configuration {
  IdentifyFlowSink() { this = "IdentifyFlowSink" }

  override predicate isSource(DataFlow::Node nd) {
    //     const db = new sqlite3.Database(
    exists(NewExpr newdb |
      newdb.getCalleeName() = "Database" and
      nd.asExpr() = newdb
    )
  }

  override predicate isSink(DataFlow::Node nd) {
    //     db.exec(query);
    exists(Expr db, MethodCallExpr exec |
      exec.getMethodName() = "exec" and
      db = exec.getReceiver() and
      nd.asExpr() = db
    )
  }
}

from IdentifyFlowSink cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink, source, sink, "Database originating $@", source, "here"
