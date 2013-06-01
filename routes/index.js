
/*
 * GET home page.
 */

exports.index = function(req, res){
  res.render('index', { title: 'Express' });
};

exports.client = function(req, res) {
	res.render('client');
}

exports.server = function(req, res) {
	res.render('server');
}