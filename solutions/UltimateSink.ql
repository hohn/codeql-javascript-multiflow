import javascript

// Ultimate source
// ----------------
//     var line = stdinBuffer.toString();
predicate uSource(MethodCallExpr sbts) {
    //  sbts.getReceiver().(DotExpr).getPropertyNameExpr().(Identifier).getName() = "toString"
    sbts.getMethodName().matches("%toString%") 
}

// Ultimate sink
// ----------------
//     db.exec(query);
predicate uSink(MethodCallExpr dbe) {
    //  sbts.getReceiver().(DotExpr).getPropertyNameExpr().(Identifier).getName() = "toString"
    dbe.getMethodName().matches("%exec%") 
}


// Intermediate flow sink
// ------------------------
// Connect
//     const db = new sqlite3.Database(
// to its use
//     db.exec(query);
// 
// class IntermediateSink extends DataFlow::Configuration {
//   IntermediateSink() { this = "IntermediateSink" }

//   override predicate isSource(DataFlow::Node nd) {
//     exists(JsonParserCall jpc | nd = jpc.getOutput())
//   }

//   override predicate isSink(DataFlow::Node nd) { exists(DataFlow::PropRef pr | nd = pr.getBase()) }
// }

// from IntermediateSink cfg, DataFlow::Node source, DataFlow::Node sink
// where cfg.hasFlow(source, sink)
// select sink, "Property access on JSON value originating $@.", source, "here"

from MethodCallExpr sbts
where uSource(sbts)
select sbts