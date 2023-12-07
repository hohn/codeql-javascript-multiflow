function sus() {
    var value = this.getParameter('value');

    var ua = new GR('ust');

    if (funnyvar) {
        nothing()
    }
    else {
        if (ua.safeToWrite()) {
            ua.setValue('status', value);
            ua.update();
        }
    }
    if (funnyvar) {
        nothing()
    }
    else {
        if (ua.safeToWrite()) {
            ua.setValue('status', value);
            ua.update();
        }
    }

    ua.next();
    ua.setValue('status', value);
    ua.update(); // unsafe

}
