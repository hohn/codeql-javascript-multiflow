var SampleUtility = function () {
    var value = this.getParameter('value');

    var ua = new GR('users');
    ua.query();

    if (!ua.hasNext()) {
        ua.initialize();
        ua.setValue('status', value);
        ua.insert();
    }
    else {
        ua.next();
        ua.setValue('status', value);
        ua.update();
    }
}
