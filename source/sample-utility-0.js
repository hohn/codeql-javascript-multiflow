var SampleUtility = function(){};
SampleUtility.prototype = Object.extendsObject(Processor, {
    
    setUserStatus: function() {
        var value = this.getParameter('value');

        var ua = new GR('users');
        ua.query();
        
        if(!ua.hasNext()){
            ua.initialize();
            ua.setValue('status',value);
            ua.insert();
        }
        else {
            ua.next();
            ua.setValue('status',value); // unsafe
            ua.update();
            // Nested if() test.
            if (ua.safeToWrite()) {
                ua.setValue('status', value); // safe
                ua.update();
            }        
        }


    },
    
    type: 'SampleUtility'
});
