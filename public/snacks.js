$(document).ready(function() {
    function vote(value) {
        return function(e) {
            var articleElement = $(this).closest('.article');
            var articleId = articleElement.data('id');

            $.ajax({
              type: 'POST',
              url: '/articles/' + articleId + '/' + value,
              dataType: 'json',
              success: function(data) { 
                  var tally = articleElement.find('.tally');
                  var oldScore = tally.text();
                  tally.text(data);
                  if (oldScore != data) articleElement.find('.' + value).toggleClass('voted');
              }
             });
        }
    };
    $('.upvote').bind('click', vote('upvote'));
    $('.downvote').bind('click', vote('downvote'));
    
    var tagHash = {};
    $('.delete-tag').bind('click', function(e) {
        e.preventDefault();
        var bubble = $(this).closest('span');
        var tagname = bubble.data('name');
        tagHash[tagname] = 'remove';
        $('.taghash').val(JSON.stringify(tagHash));
        bubble.remove();
    });
    $('.tag-input').keypress(function(e) {
        if(e.which == 13) {
            e.preventDefault();
            var tagname = $(this).val();
            $('.taglist').append("<span class='label' data-name='" + tagname + "'>" + tagname + "<a href='' class='delete-tag'>x</a></span>");
            tagHash[tagname] = 'add';
            $('.taghash').val(JSON.stringify(tagHash));
            $(this).val('');
        }
    });
});
