/**
 * @kind path-problem
 * @problem.severity warning
 * @id javascript/example/multiflow
 */

import javascript
// XX: debug flow query
// import semmle.javascript.explore.ForwardDataFlow
import DataFlow::PathGraph

// Flow to consider:
// var value = this.getParameter('value'); //: source 1
// var ua = new GR('status');              //: source 2
// ua.setValue('status',value);            //: taint step
// ua.update();                            //: sink (if from source 2)
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
  exists(DotExpr temp, MethodCallExpr mce, VarAccess gr, VarAccess postgr|
    temp.getPropertyName() = "setValue" and
    mce.getReceiver() = temp.getBase() and
    gr = mce.getReceiver() and
    pred.asExpr() = mce.getArgument(1) and
    // Taint all accesses after setValue call.
    // Trying data flow, this would be:
    // succ = gr.flow().getASuccessor+() and
    //
    // Using control flow:    
    gr.getASuccessor+() = postgr and
    succ.asExpr() = postgr
    )

}

VarRef methodCalled(string name) {
  exists(DotExpr temp |
    temp.getPropertyName() = name and
    result = temp.getBase()
  )
}

// ua.update();                            //: sink (if from source 2)
DotExpr updateExpression() { result.getPropertyName() = "update" }

VarRef recordUpdate() { result = updateExpression().getBase() }

// var ua = new GR('status');     //: source 2
class GR extends NewExpr {
  GR() { this.getCalleeName() = "GR" }
}

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
      grUpdate.getName() = "ua"
    )
  }
}

from FromRequestToGrUpdate dataflow, DataFlow::PathNode source, DataFlow::PathNode sink
where dataflow.hasFlowPath(source, sink)
select sink, source, sink, "Data flow from $@ to $@.", source, source.toString(), sink, sink.toString()
