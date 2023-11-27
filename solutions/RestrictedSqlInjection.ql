/**
 * @kind path-problem
 */

import javascript
import DataFlow::PathGraph

// Ultimate source
// ----------------
//     var line = stdinBuffer.toString();
Expr uSource(MethodCallExpr sbts) {
  sbts.getMethodName().matches("%toString%") and
  result = sbts
}

// Ultimate sink
// ----------------
//     db.exec(query);
Expr uSink(MethodCallExpr exec) {
  exec.getMethodName() = "exec" and
  result = exec.getArgument(0)
}

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

class IdentifyFlowSink extends TaintTracking::Configuration {
  IdentifyFlowSink() { this = "IdentifyFlowSink" }

  override predicate isSource(DataFlow::Node nd, DataFlow::FlowLabel lbl) {
    //     const db = new sqlite3.Database(
    exists(NewExpr newdb |
      newdb.getCalleeName() = "Database" and
      nd.asExpr() = newdb and
      lbl instanceof FlowSinkOrigin
    )
  }

  override predicate isSink(DataFlow::Node nd, DataFlow::FlowLabel lbl) {
    //     db.exec(query);
    exists(Expr db, MethodCallExpr exec |
      exec.getMethodName() = "exec" and
      db = exec.getReceiver() and
      nd.asExpr() = db and
      lbl instanceof FlowSinkOrigin
    )
  }
}

class UltimateFlowCfg extends TaintTracking::Configuration {
  UltimateFlowCfg() { this = "UltimateFlowCfg" }

  override predicate isSource(DataFlow::Node nd) { nd.asExpr() = uSource(_) }

  override predicate isSink(DataFlow::Node nd) { nd.asExpr() = uSink(_) }
}

from
  UltimateFlowCfg ucfg, DataFlow::PathNode usource, DataFlow::PathNode usink, IdentifyFlowSink cfg,
  DataFlow::Node source, DataFlow::Node sink
where
  cfg.hasFlow(source, sink) and
  ucfg.hasFlowPath(usource, usink) and
  exists(MethodCallExpr exec |
    sink.asExpr() = exec.getReceiver() and
    usink.getNode().asExpr() = exec.getAnArgument()
  )
select usink, usource, usink, "Sql injected from $@", usource, "here"
