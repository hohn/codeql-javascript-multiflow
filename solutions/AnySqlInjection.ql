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

class UltimateFlow extends DataFlow::FlowLabel {
  UltimateFlow() { this = "UltimateFlow" }
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
    or
    nd.asExpr() = uSource(_) and
    lbl instanceof UltimateFlow
  }

  override predicate isSink(DataFlow::Node nd, DataFlow::FlowLabel lbl) {
    //     db.exec(query);
    exists(Expr db, MethodCallExpr exec |
      exec.getMethodName() = "exec" and
      db = exec.getReceiver() and
      nd.asExpr() = db and
      lbl instanceof FlowSinkOrigin
    )
    or
    nd.asExpr() = uSink(_) and
    lbl instanceof UltimateFlow
  }
}

class UltimateFlowCfg extends TaintTracking::Configuration {
  UltimateFlowCfg() { this = "UltimateFlowCfg" }

  override predicate isSource(DataFlow::Node nd) { nd.asExpr() = uSource(_) }

  override predicate isSink(DataFlow::Node nd) { nd.asExpr() = uSink(_) }
}

// from IdentifyFlowSink cfg, DataFlow::PathNode source, DataFlow::PathNode sink
// where cfg.hasFlowPath(source, sink)
// select sink, source, sink, "Database originating $@", source, "here"
from UltimateFlowCfg cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink, source, sink, "Sql injected from $@", source, "here"
