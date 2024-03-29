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
    // Using control flow
    gr.getASuccessor+() = postgr and
    succ.asExpr() = postgr
  )
  or
  exists(DotExpr stw_do, MethodCallExpr stw_mc, VarAccess stw_va, 
  DotExpr sv_do, MethodCallExpr sv_mc, VarAccess sv_va |
    // A safeToWrite ...
    stw_do.getPropertyName() = "safeToWrite" and
    stw_mc.getReceiver() = stw_do.getBase() and
    stw_va = stw_mc.getReceiver() and
    // ... followed by a  setValue
    sv_do.getPropertyName() = "setValue" and
    sv_mc.getReceiver() = sv_do.getBase() and
    sv_va = sv_mc.getReceiver() and
    //
    stw_mc.getASuccessor+() = sv_va and
    // The setValue taints the safeToWrite.  This is going up the CFG, which is
    // backwards.  
    // It's a lie to get the sanitizer to work.
    pred.asExpr() = sv_va and 
    succ.asExpr() = stw_va 
  )
}


predicate tsTest1(DataFlow::Node pred, DataFlow::Node succ)  {
  setValueTaintStep(pred, succ)
  and 
  pred.asExpr().getLocation().getFile().getBaseName().matches("%sample%1%")  
}

// Def-Use special handling.  Not needed here, but a good example of recursive predicates.
// - Include sanitizer check when flagging successive object member calls in taint
//   step.
// - Stop at
//       ua.safeToWrite()
predicate sanitizerCheckedSuccessor(ControlFlowNode gr, ControlFlowNode postgr) {
  gr.getASuccessor() = postgr and
  not inSafeToWrite(postgr)
  or
  exists(ControlFlowNode p |
    sanitizerCheckedSuccessor(gr, p) and
    not gr.getASuccessor() = postgr and
    p.getASuccessor() = postgr
  )
  // The final postgr needs to be a VarAccess for this query, but for the
  // recursion we need to be able to traverse expressions.
}

predicate inSafeToWrite(ControlFlowNode p) {
  exists(
    //  DotExpr temp, MethodCallExpr mce,
    IfStmt if_
  |
    // XX:
    if_.getAChild+().getFirstControlFlowNode() = p
    // and
    // temp.getPropertyName() = "safeToWrite" and
    // p = mce.getReceiver() and
    // p = temp.getBase()
  )
}

// Preparation for including a sanitizer check when flagging successive object
// member calls in taint step
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

  override predicate isSanitizerGuard(TaintTracking::SanitizerGuardNode nd) {
    nd instanceof CanWriteGuard
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

class CanWriteGuard extends TaintTracking::SanitizerGuardNode, DataFlow::CallNode {
  CanWriteGuard() { this.getCalleeName() = "safeToWrite" }

  override predicate sanitizes(boolean outcome, Expr e) {
    // outcome is the result of the conditional (the true or false branch)
    outcome = true and
    e = this.getReceiver().asExpr()
  }
}

from FromRequestToGrUpdate dataflow, DataFlow::PathNode source, DataFlow::PathNode sink
where dataflow.hasFlowPath(source, sink)
select sink, source, sink, "Data flow from $@ to $@.", source, source.toString(), sink,
  sink.toString()
