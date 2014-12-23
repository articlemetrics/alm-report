$(function () {
  $('.facets .see_all a').click(function (e) {
    e.preventDefault();
    $(this).parent().parent().find('.additional').toggle();
    if($(this).text() == 'Hide all') {
      $(this).text('See all')
    } else {
      $(this).text('Hide all')
    }
  })
})
