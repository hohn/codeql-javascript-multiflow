/**
 * @kind path-problem
 * @problem.severity warning
 * @id javascript/example/multiflow
 */

import javascript
// XX: debug flow query
// import semmle.javascript.explore.ForwardDataFlow
import DataFlow::PathGraph
import DataFlow as DF

// Flow to consider:
//
// var value = this.getParameter('value'); //: source 1
// var ua = new GR('status');              //: source 2
// ua.setValue('status',value);            //: taint step
// ua.update();                            //: sink (if from source 2)
//
// var value = this.getParameter('value'); //: source 1
class ParameterSource extends CallExpr {
  ParameterSource() {
    exists(Expr inst |
      this.getCalleeName() = "getParameter" and
      (this.getReceiver().(ThisExpr) = inst or this.getReceiver().(Identifier) = inst)
    )
  }
}

// ua.setValue('status',value);            //: taint step
predicate setValueTaintStep(DataFlow::Node pred, DataFlow::Node succ) {
  exists(DotExpr temp, MethodCallExpr mce, VarAccess gr, VarAccess postgr |
    temp.getPropertyName() = "setValue" and
    mce.getReceiver() = temp.getBase() and
    gr = mce.getReceiver() and
    pred.asExpr() = mce.getArgument(1) and
    //
    // Taint all accesses after setValue call.
    // Trying data flow, this would be:
    // succ = gr.flow().getASuccessor+() and
    //
    // Using control flow:
    // 1. without sanitizer
    // gr.getASuccessor+() = postgr and
    // succ.asExpr() = postgr
    //
    // 2. with recursive predicate, no sanitizer
    recursiveSuccessor(gr, postgr) and
    succ.asExpr() = postgr
    // // 3. with recursive predicate, with sanitizer
    // sanitizerCheckedSuccessor(gr, postgr) and
    // succ.asExpr() = postgr
  )
}

// Def-Use special handling:
// Include sanitizer check when flagging successive object member calls in taint step
predicate recursiveSuccessor(ControlFlowNode gr, ControlFlowNode postgr) {
  gr.getASuccessor() = postgr
  or
  exists(ControlFlowNode p |
    recursiveSuccessor(gr, p) and
    p.getASuccessor() = postgr
  )
  // The final postgr needs to be a VarAccess for this query, but for the
  // recursion we need to be able to traverse expressions.
}

// source 2 to sink flow
DF::SourceNode grType(DF::TypeTracker t) {
  t.start() and
  exists(GR gr | result.asExpr() = gr)
  or
  exists(DF::TypeTracker t2 | result = grType(t2).track(t2, t))
}

DF::SourceNode grType() { result = grType(DF::TypeTracker::end()) }

// ua.update();                            //: sink (if from source 2)
DotExpr updateExpression() { result.getPropertyName() = "update" }

VarRef recordUpdate() { result = updateExpression().getBase() }

// var ua = new GR('status');     //: source 2
class GR extends NewExpr {
  GR() { this.getCalleeName() = "GR" }
}

// The global flow configuration
class FromRequestToGrUpdate extends TaintTracking::Configuration {
  FromRequestToGrUpdate() { this = "FromRequestToGrUpdate" }

  override predicate isSource(DataFlow::Node source) {
    exists(ParameterSource getParameter | source.asExpr() = getParameter)
  }

  override predicate isAdditionalTaintStep(DataFlow::Node pred, DataFlow::Node succ) {
    setValueTaintStep(pred, succ)
  }

  override predicate isSink(DataFlow::Node sink) {
    exists(VarRef grUpdate |
      sink.asExpr() = recordUpdate() and
      grUpdate = sink.asExpr() and
      grUpdate.getName() = "ua" and
      // It's only a sink if it connects to source 2
      grUpdate.flow().getALocalSource() = grType()
    )
  }
}

from FromRequestToGrUpdate dataflow, DataFlow::PathNode source, DataFlow::PathNode sink
where dataflow.hasFlowPath(source, sink)
select sink, source, sink, "Data flow from $@ to $@.", source, source.toString(), sink,
  sink.toString()
