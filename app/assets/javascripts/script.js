// handles the article selection and saving on add-articles.html
jQuery(function(d, $){
  (function(){

    var $list_count = $('.list-count');
    var initial_list_count = parseInt($list_count.text(), 10);
    var $preview_list_count = $('.preview-list-count');
    var results_span_pages = ($('.pagination-number').length > 1);

    var ARTICLES_PER_PAGE = 25;

    return {
      init : function() {
        // update the header and the sidebar with the current list count
        this.updateListCount(initial_list_count);

        // set up event handlers
        $('.check-save-article').on("click", jQuery.proxy(this.checkboxClickHandler, this));
        $('.select-all-articles-link').on("click", { 'mode' : "SAVE" }, jQuery.proxy(this.toggleAllArticles, this));
        $('.unselect-all-articles-link').on("click", { 'mode' : "REMOVE" }, jQuery.proxy(this.toggleAllArticles, this));
      },

      updateListCount : function(new_count) {
        // update "your list" box in header
        $list_count.text(new_count);

        // update preview list button
        $preview_list_count.val("Preview List (" + new_count + ")");
      },

      checkboxClickHandler : function(e) {
        var $checkbox = $(e.target);

        // create some data that we want to send to the server
        var ajax_data = {
          // grab the article ID from the checkbox value
          article_id : [$checkbox.val()],

          // set the "mode" based on what state the checkbox is transitioning to
          // NOTE: this handler runs *after* the checkbox element has been 
          // updated so we check the "checked" prop.
          mode : $checkbox.prop("checked") ? "SAVE" : "REMOVE"
        };

        var $container = $checkbox.parent('.article-info');

        // show the user immediate visual feedback that we're doing something
        this.displayProgressIndicators($container, ajax_data.mode);

        // pass the data to the server to update the session
        // NOTE: update server expects an array (or collection) of checkboxes 
        // and containers to iterate over later on
        this.updateServer(ajax_data, $checkbox, $container);
      },

      // expects a jquery collection of containers to operate on
      displayProgressIndicators : function($containers, mode) {
        // we need to clear out the result message before trying to display a 
        // "updating" message since they occupy the same space
        // $containers.find('.result').remove();

        // compose a message based on the "mode"
        // var initial_msg = (mode == "SAVE") ? "Saving..." : "Removing...";

        // insert the message into the DOM
        // $containers.find('a').after("<span class='updating'>" + initial_msg + "</span>");
        $containers.find('a').after("<span class='updating'><\/span>");
      },

      toggleAllArticles : function(e) {
        // operate only on the checkboxes that we need to based on what's 
        // selected and what "mode" we're in. :checked/:not(:checked) FTW!
        var $checkboxes = $(
          (e.data['mode'] == 'SAVE') ? 
            ".check-save-article:not(:checked)" : 
            ".check-save-article:checked"
        );

        var $containers = []; // this will eventually be a jquery collection

        // this data will be serialized in the ajax request
        var ajax_data = {
          article_ids : [],
          mode : e.data['mode']
        };

        // this doesn't feel idiomatic to jquery. it also needs refactoring
        // FIXME: refactor this so it can be used by checkboxClickHandler
        $checkboxes.each(jQuery.proxy(function(idx, c) {
          var checkbox = $(c);

          // actually check the checkbox since we did not physically interact with it
          checkbox.prop("checked", (e.data['mode'] == 'SAVE'));

          // grab the value from the checkbox; that's what we want to send to the server
          ajax_data['article_ids'].push(checkbox.val());

          // store a ref to the container; we need to operate on that later
          var $container = checkbox.parent('.article-info');
          $containers.push($container);

          // displays the progress indicator for the checkbox's container
          this.displayProgressIndicators($container, ajax_data.mode);
        }, this));

        // now that we have our array of container nodes, turn it into a jquery 
        // collection so we can more easily operate on it later
        $containers = $($containers);

        if (ajax_data["article_ids"].length) {
          // pass the data to the server to update the session
          this.updateServer(ajax_data, $checkboxes, $containers);
        }
      },

      updateServer : function(ajax_data, $checkboxes, $containers) {
        // disable the checkboxes while we await confirmation the server that it's been updated
        $checkboxes.prop('disabled', true);
        $.ajax('/update-session', {
          type: 'POST',

          // Unless we set this header, rails will silently refuse to save anything
          // to the session!
          beforeSend: function(xhr) {
              xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))
              },
          data : ajax_data,
        
          // NOTE: ajaxResponseHandler requires checkboxes and containers passed in to the handler
          // so that we can update the correct article(s)!
          complete : jQuery.proxy(this.ajaxResponseHandler, this, ajax_data.mode, $checkboxes, $containers)
        });
      },

      // expects a jquery collections of checkboxes and containers
      ajaxResponseHandler : function(mode, $checkboxes, $containers, xhr, status) {

        // collection of values that controls what kind of status message gets 
        // inserted. values change based on XHR status
        var status_data;

        // flag to determine if resetting checkboxes is necessary
        var error_occurred = false;

        // FIXME: !!! ATTENTION !!!
        // this logic will most certainly need to be modified once the JS API is 
        // written in order to handle the multiple layers of status (HTTP, 
        // businiess logic, etc.)

        switch(status) {

          // possible values for 'status' from AJAX call per jquery docs
          //  - success
          //  - notmodified
          //  - error
          //  - timeout
          //  - abort
          //  - parsererror

          case "success" :
            status_data = {
              class_name : "success",
              text : (mode == "SAVE") ? "Saved" : "Removed",
              img_class_name : "success-tick"
            };
            break;

          case "error" :
          default:
            // this branch indicates that an error has occurred, so set the flag
            error_occurred = true;

            status_data = {
              class_name : "error",
              text : "Error!",
              img_class_name : ""
            };
            break;
        }

        // update the containers' progress indicators based on the status data
        this.updateProgressIndicators($containers, status_data);

        // now that the server returned a response, we can re-enable the 
        // checkboxes so the user can do something else with the article or try 
        // again (on the off chance the AJAX response was an error and the 
        // article state wasn't set correctly.)
        $checkboxes.prop('disabled', false);

        // if there was an error, we need to reset the state of the checkbox to 
        // what it as before the user interacted with it. (hence the not operator)
        if (error_occurred) {
          // console.log("error occurred; reverting checkbox to previous state: ", !($checkboxes.eq(0).prop('checked')));

          // note that $checkboxes is an array, so we need the first element's 
          // value to determine what to set all the others to.
          $checkboxes.prop('checked', !($checkboxes.eq(0).prop('checked')));
        }

        // now that we have a response from the server and we've adjusted the 
        // checkbox states if necessary, re-query the DOM to figure out how 
        // many article are actually selected on this page.
        var selected_articles_count = $(".check-save-article:checked").length;

        // update "your list" and "preview list" buttons with new article count
        this.updateListCount(initial_list_count + selected_articles_count);

        // one last thing to do if no errors occurred...
        if (!error_occurred) {
          // show "select all articles across all pages" message if this 
          // result set spans multiple pages and we've just checked all the 
          // articles on this page
          if ( results_span_pages && (selected_articles_count == ARTICLES_PER_PAGE) ) {
            $('#select-articles-message-text').html("The " + ARTICLES_PER_PAGE + " articles on this page have been selected.");
            $('.select-articles-message').removeClass("invisible");

          // in all other cases, just hide it. (it's easier this way)
          } else {
            $('#select-articles-message-text').html("");
            $('.select-articles-message').addClass("invisible");
          }
        }

      },

      updateProgressIndicators : function($containers, status_data) {
        // iterate over all the containers that were interacted with
        $containers.each(function(idx, c) {
          // bare DOM node is each element of the array/collection
          c = $(c);

          // remove the temp message
          c.find(".updating").remove();

          // insert the result message
          // c.find("a").after([
          //   "<span class='result " + status_data.class_name + "'>",
          //     status_data.text,
          //     "<span class='" + status_data.img_class_name + "'><\/span>",
          //   "<\/span>"
          // ].join("\n"));

          // // perform a 2 second fade out the message we just added, after 3 seconds
          // var updated_msg = c.find("." + status_data.class_name);
          // setTimeout(function() { updated_msg.fadeOut(2000); }, 3000);
        });
      }

    };

  })().init();
}(document, jQuery));


// handles the fixed position navigation on the right
jQuery(function(d, $){
  (function(){

    var $aside_container = $('.aside-container');
    var container_width = $('.wrapper').width();

    function scrollHandler() {
      // fix the position of the .aside_container if the viewport has 
      // scrolled 40 pixels beyond the height of the nav
      if ( $(window).scrollTop() > ($('.nav-area').height() + 40) ) {

        // align the ".aside-container" to the right of the layout
        $aside_container.addClass('scroll-fixed');
        setRightEdge();
      }

      else {
        $aside_container.removeClass('scroll-fixed');
      }
    }

    function resizeHandler() {
      setRightEdge();
    }

    function setRightEdge() {
      // the layout is centered, so we need half of the difference between the 
      // viewport width and the layout width
      var right_edge = parseInt( (($(window).width() - container_width) / 2), 10);
      $aside_container.css('right', right_edge);
    }

    return {
      init : function() {

        // only attach event handlers if the .aside-container exists.
        if ($aside_container.hasClass('rollover-fixed')) {
          // the main logic executes on the scroll event handler
          $(window).scroll(scrollHandler);

          // since the page is centered, we also need a resize handler to 
          // manage the positioning of the right side of the ".aside-container" 
          // when the window is resized 
          $(window).resize(resizeHandler);
        }

      }
    };

  })().init();
}(document, jQuery));


// handles the addition of fields
jQuery(function(d, $){
  $('#add-fields').on("click", function(e) {
    var num_fields_to_add = 5;

    // stop the event (#add-fields is a input type="submit")
    e.preventDefault();

    // make field_count zero-based
    var last_field_id = $(".doi-pmid-form > .input-holder").length;

    // holds the markup for the fields
    var fields_html = "";

    // generate the markup for the new fields
    for (var i = last_field_id; i <= last_field_id + num_fields_to_add; i++) {
      fields_html += [
        '<div class="input-holder">',
          '<label for="doi-pmid-' + i + '">DOI/PMID</label>',
          '<div>',
            '<input type="text" name="" id="doi-pmid-' + i + '" />',
          '</div>',
        '</div>'
      ].join("\n");
    }

    // add all the markup in one fell swoop
    // "-2" because the last .input-holder is for the submit buttons and 
    // we want the new fields before it.
    $(".doi-pmid-form .input-holder").eq(-2).after(fields_html);
  });
}(document, jQuery));


// handles the dismissing of error messages
jQuery(function(d, $){
  var j = $(".doi-pmid-form .error-holder").children(".doi-pmid-remove").length ;

  $('.doi-pmid-remove').on("click", function() {
    var $current_element = $(this);                
    var $current_error_holder = $current_element.parent('.error-holder');                    

    $current_error_holder.find('.error-message').remove();
    $current_error_holder.parent('.input-holder').find('label').removeClass('error-color');
    $current_error_holder.parent('.input-holder').find('div').removeClass('error-holder');
    $current_element.siblings('input').val('');
    $current_element.remove();

    j = j -1;

    if (j == 0){
      $('.error-title').addClass('error-title-removal');
      $('.upload-error-title').addClass('error-title-removal');
    }
  });
}(document, jQuery));


// add placeholder polyfill for older browsers
if (jQuery.fn.placeholder) {
  jQuery(function(){
    $('input, textarea').placeholder();
  });
}


// handles the date pickers for the custom date range
jQuery(function(d, $){
  if (!jQuery.fn.datepicker) { return; }

  var $date_input_fields = $(".date-input-fields");

  $('#publication_days_ago').change(function() {
    var option = this.options[this.selectedIndex];

    if (($(option).text()) == "Custom date range") {
      $date_input_fields.css('display','block');
    }
    else{
      $date_input_fields.css('display','none');
    }
  });


  var $datepicker1 = $('#datepicker1');
  var $datepicker2 = $('#datepicker2');

  $datepicker1.datepicker({
    dateFormat: 'mm-dd-yy',
    onSelect: function(dateText, instance) {
      date = $.datepicker.parseDate(instance.settings.dateFormat, dateText, instance.settings);
      date.setMonth(date.getMonth());
      $datepicker2.datepicker("option", "minDate", date);
      $datepicker1.addClass('hasdate-picker-active');
    }
  });

  $datepicker2.datepicker({
    dateFormat: 'mm-dd-yy',
    onSelect: function(dateText, instance) {
      $datepicker2.addClass('hasdate-picker-active');
    }
  });
}(document, jQuery));


// manages the welcome back modal
jQuery(function(d, $){
  var $welcome_back_container = $('.welcome-back-container');
  if (!$welcome_back_container) { return; }

  var $welcome_back_holder = $('.welcome-back-holder');
  var $welcome_back_holder_height = parseInt((($(window).height() - $welcome_back_holder.height()) / 2), 10);

  if ($('.welcome-back-wrapper').hasClass('welcome-back-container')) {
    $welcome_back_holder.css('margin-top', $welcome_back_holder_height);
  }

  $('.welcome-close-btn').click(function(){
    $welcome_back_container.hide();
  });

  $welcome_back_container.css('height', $(document).height());
}(document, jQuery));


// display the error message on hover over of "ignore errors" button on 
// the "upload-file.fix-errors" page
jQuery(function(d, $){
  var $upload_file_error_input_holder_p = $('.upload-file-error-input-holder p');

  $('.ignore-errors').hover(function(){
    $upload_file_error_input_holder_p.css('display','inline-block');               
  },function(){
    $upload_file_error_input_holder_p.css('display','none');
  });
}(document, jQuery));
