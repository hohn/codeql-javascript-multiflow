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
// Expr uSink(MethodCallExpr exec) {
//     //   exec.getMethodName() = "exec" and
//     //   result = exec.getArgument(0)
//     exists(IdentifyFlowSink cfg, DataFlow::Node source, DataFlow::Node sink |
//         cfg.hasFlow(source, sink) and
//         result = sink.asExpr()
//     )
// }
// Flow sink origin
// ------------------------
// Connect
//     const db = new sqlite3.Database(
// to its use
//     db.exec(query);
//
predicate isDBCreate(DataFlow::SourceNode nd) {
  exists(NewExpr newdb |
    newdb.getCalleeName() = "Database" and
    nd.asExpr() = newdb
  )
}

import DataFlow as DF

DataFlow::SourceNode myType(DataFlow::TypeTracker t) {
  t.start() and
  isDBCreate(result)
  or
  exists(DF::TypeTracker t2 | result = myType(t2).track(t2, t))
}

DF::SourceNode myType() { result = myType(DF::TypeTracker::end()) }

class UltimateFlowCfg extends TaintTracking::Configuration {
  UltimateFlowCfg() { this = "UltimateFlowCfg" }

  override predicate isSource(DataFlow::Node nd) { nd.asExpr() = uSource(_) }

  override predicate isSink(DataFlow::Node nd) {
    exists(Expr db, MethodCallExpr exec |
      exec.getMethodName() = "exec" and
      db = exec.getReceiver() and
      nd.asExpr() = exec.getAnArgument() and
      db.flow().getALocalSource() = myType()
    )
  }
}

from UltimateFlowCfg ucfg, DataFlow::PathNode usource, DataFlow::PathNode usink
where ucfg.hasFlowPath(usource, usink)
select usink, usource, usink, "Sql injected from $@", usource, "here"
