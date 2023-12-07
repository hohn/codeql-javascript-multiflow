function sus() {
    var value = this.getParameter('value');

    var ua = new GR('ust');

    if (funnyvar) {
        nothing()
    }
    else {
        nothing()
        if (ua.safeToWrite()) {
            ua.setValue('status', value);
            ua.update();
        }
    }

    if (!ua.hasNext()) {
        ua.initialize();
        ua.setValue('status', value);
        ua.insert();
    }
    else {
        ua.next();
        ua.setValue('status', value); 
        ua.update(); // unsafe
        if (ua.safeToWrite()) {
            ua.setValue('status', value); // safe
            ua.update();
        }
    }
}
