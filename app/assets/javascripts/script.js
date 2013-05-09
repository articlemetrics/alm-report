// handles the article selection and saving on add-articles.html
jQuery(function(d, $){
  (function(){

    var $list_count = $('.list-count');
    var initial_list_count = parseInt($list_count.text(), 10);
    var preview_list_count = initial_list_count;
    var $preview_list_count_elem = $('.preview-list-count');
    var results_span_pages = ($('.pagination-number').length > 1);

    // Be sure to keep these two constants in sync with the ruby constants of
    // the same name in custom.rb.
    var RESULTS_PER_PAGE = 25;
    var ARTICLE_LIMIT = 500;

    return {
      init : function() {
        // update the header and the sidebar with the current list count
        this.updateListCount(initial_list_count);

        // set up event handlers
        $('.check-save-article').on("click", jQuery.proxy(this.checkboxClickHandler, this));
        $('.select-all-articles-link').on("click", { 'mode' : "SAVE" }, jQuery.proxy(this.toggleAllArticles, this));
        $('.unselect-all-articles-link').on("click", { 'mode' : "REMOVE" }, jQuery.proxy(this.toggleAllArticles, this));
        $('.reset-btn').on("click", { 'mode' : "REMOVE" }, jQuery.proxy(this.toggleAllArticles, this));
        $('#select_all_searchresults').on("click", jQuery.proxy(this.selectAllSearchResults, this));
      },

      // Replaces the preview list counts in the UI with the new value.
      updateListCount : function(new_count) {
        preview_list_count = new_count;
        
        // update "your list" box in header
        $list_count.text(new_count);

        // update preview list button
        $preview_list_count_elem.val("Preview List (" + new_count + ")");
      },
      
      // Increments the preview list counts in the UI by the specified delta, which
      // can be positive or negative.
      incrementListCount : function(delta) {
        this.updateListCount(preview_list_count + delta);
      },

      checkboxClickHandler : function(e) {
        var $checkbox = $(e.target);

        // If we are over the limit, and it's a check event, don't do anything
        // (and uncheck the checkbox).
        if ($checkbox.prop("checked") && preview_list_count >= ARTICLE_LIMIT) {
          $checkbox.prop("checked", false);
          this.showErrorDialog("article-limit-error-message");
          return;
        }

        // create some data that we want to send to the server
        var ajax_data = {
          // grab the article ID from the checkbox value
          article_ids : [$checkbox.val()],

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
        var json_resp = $.parseJSON(xhr.responseText);

        // collection of values that controls what kind of status message gets 
        // inserted. values change based on XHR status
        var status_data;

        // flag to determine if resetting checkboxes is necessary
        var error_occurred = false;
        if (status == "success") {
          if (json_resp.status == "success") {
            status_data = {
              class_name : "success",
              text : (mode == "SAVE") ? "Saved" : "Removed",
              img_class_name : "success-tick"
            };
          } else if (json_resp.status == "limit") {
            error_occurred = true;
            status_data = {
              class_name : "error",
              text : "Error!",
              img_class_name : ""
            };
            this.showErrorDialog("article-limit-error-message");
          }
        } else {

            // this branch indicates that an error has occurred, so set the flag
            error_occurred = true;
            status_data = {
              class_name : "error",
              text : "Error!",
              img_class_name : ""
            };
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
        this.incrementListCount(json_resp.delta);

        // one last thing to do if no errors occurred...
        if (!error_occurred) {
          // show "select all articles across all pages" message if this 
          // result set spans multiple pages and we've just checked all the 
          // articles on this page
          if ( results_span_pages && (selected_articles_count == RESULTS_PER_PAGE) ) {
            $('#select-articles-message-text').html("The " + RESULTS_PER_PAGE + " articles on this page have been selected.");
            var select_all_message = $('#select-all-articles-message-text').html();
            select_all_message = select_all_message.replace("__SELECT_ALL_NUM__",
                ARTICLE_LIMIT - preview_list_count);
            $('#select-all-articles-message-text').html(select_all_message);
            $('.select-articles-message').removeClass("invisible");
            
            // We have to re-add this onclick, since the above DOM manipulation
            // apparently un-does it.
            $('#select_all_searchresults').on("click",
                jQuery.proxy(this.selectAllSearchResults, this));

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
      },
      
      // Handles the user clicking on the "Select all nnn articles" link.  Selects
      // *all* of the articles from the search, not just those on the current page.
      // (Subject to the article limit.)
      selectAllSearchResults : function(e) {
        var url_params = window.location.search.substr(1);  // Remove leading "?"
        
        // Convert to dict for ajax call.
        var data = {};
        var pairs = url_params.split("&");
        for (i in pairs) {
          var split = pairs[i].split("=");
          
          // We need to convert "+" to " ", which none of the stock javascript functions
          // seem to handle correctly.  See http://unixpapa.com/js/querystring.html
          data[split[0]] = decodeURIComponent(split[1].replace(/\+/g, " "));
        }

        $("#gray-out-screen").css({
          opacity: 0.7,
          "width": $(document).width(),
          "height": $(document).height()
        });
        $("body").css({"overflow": "hidden"});
        $("#select-all-spinner").css({"display": "block"});

        $.ajax("/select-all-search-results", {
          type: "POST",
          
          // Unless we set this header, rails will silently refuse to save anything
          // to the session!
          beforeSend: function(xhr) {
              xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))
              },
          data: data,
          complete: jQuery.proxy(this.selectAllSearchResultsResponseHandler, this)
        });
      },
      
      selectAllSearchResultsResponseHandler : function(xhr, status) {
        $("#gray-out-screen").hide();
        $("#select-all-spinner").hide();
        $(".select-articles-message").hide();

        var json_resp = $.parseJSON(xhr.responseText);
        if (status == "success" && json_resp.status == "success") {
          var $unchecked_checkboxes = $(".check-save-article:not(:checked)");
          $unchecked_checkboxes.prop("checked", true);
          this.incrementListCount(json_resp.delta);
        } else {
          var $checked_checkboxes = $(".check-save-article:checked");
          $checked_checkboxes.prop("checked", false);
          this.showErrorDialog("solr-500-error-message");
        }
      },
      
      // Displays an error message below the navigation links.  The argument is the
      // ID of an element that contains the error message HTML.
      showErrorDialog : function(error_message_id) {
        var message = $("#" + error_message_id).html();
        var error_div = $("#error-message-div");
        error_div.html(message);
        error_div.show();
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


// handles the dismissing of error messages from the "Find Articles by DOI/PMID" page.
var dismissDoiPmidErrors = function(event) {
  var $current_element = $(event.target);
  var $current_error_holder = $current_element.parent('.error-holder');

  $current_error_holder.find('.error-message').remove();
  var $input_holder = $current_error_holder.parent('.input-holder');
  $input_holder.find('label').removeClass('error-color');
  $input_holder.find('div').removeClass('error-holder');
  $current_element.siblings('input').val('');
  $current_element.remove();
};


// Subtly different from dismissDoiPmidErrors above: this function is called
// from the ajax response handler upon successful validation of a DOI.
// It should remove any error messages, if present, and keep the value of
// the text field intact.
var dismissDoiPmidFieldError = function($error_div) {
  $error_div.find('.error-message').remove();
  var $input_holder = $error_div.parent('.input-holder');
  $input_holder.find('label').removeClass('error-color');
  $input_holder.find('div').removeClass('error-holder');
  $error_div.find('.doi-pmid-remove').remove();
};


jQuery(function(d, $){

  $('.doi-pmid-remove').on("click", dismissDoiPmidErrors);
}(document, jQuery));


// Indicates that a single field on the DOI/PMID form is invalid.  The first
// argument is the jQuery text field.
var highlightDoiPmidError = function($element, error_message) {
  var $parent_div = $($element.parentNode);
  $parent_div.attr('class', 'error-holder');
  $parent_div.children('.input-example').remove();
  if ($parent_div.children('.error-message').length == 0) {
    $parent_div.append('<p class="error-message error-color">' + error_message + '</p>');
    $parent_div.append('<span class="doi-pmid-remove">Remove</span>');

    // Need to re-add this listener since we recreated the element above.
    $('.doi-pmid-remove').on("click", dismissDoiPmidErrors);
  }
};


// Onchange handler for text fields on the "Find Articles by DOI/PMID" page.
// Performs validation to ensure the values are valid PLOS DOIs.
jQuery(function(d, $){

  $('[id^=doi-pmid-]').on("change", function() {
    var input_element = $(this)[0];
    var match = /(info:)?(doi\/)?(10\.1371\/journal\.p[a-z]{3}\.\d{7})/.exec(input_element.value);
    if (match == null || match[3] == null) {
      highlightDoiPmidError(input_element, 'This DOI is not a PLOS article');
    } else {
    
      // Validate DOI against solr.  We need to make a jsonp request to get around the
      // same-origin policy.
      var query = 'id:"' + match[3] + '"';
      $.ajax('http://api.plos.org/search', {
          type: 'GET',
          dataType: 'jsonp',
          data: {wt: 'json', q: query, fl: 'id'},
          jsonp: 'json.wrf',
          success: function(resp) {
            if (resp.response.numFound == 1) {
              
              // Remove any previous error message.
              dismissDoiPmidFieldError($(input_element).parent('.error-holder'));
            } else {
              highlightDoiPmidError(input_element, 'This paper could not be found');
            }
          }
      });
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

// add custom button and select boxes for all browsers on home, home-welcomeback, add-article and upload-file pages
if (jQuery.fn.uniform) {
  jQuery(function(){
  $('select').uniform();
  $('#add-article-select').uniform();
  $('#upload-file-field').uniform();
  $('.filename, .action').click(function(){
    $('#upload-file-field').trigger('click');
    });
  })
}

// Event handler for the sort select box on the add articles page.
jQuery(function(d, $){
  $('#search_results_sort_order_select').change(function() {
    var sort_param = this.options[this.selectedIndex].value;
    window.location.href = window.location.href + "&sort=" + encodeURIComponent(sort_param);
  });
}(document, jQuery));


// Event handler for "Show all ALMs" on the report metrics page
jQuery(function(d, $){
  $('.show-all-alms-link').click(function() {

    var linkText = $(this).text();
    var children = $(this).children();

    if (linkText.toLowerCase() === 'show all alms') {
      // display all the metric information with zero values
      $(this).next('div').find('tr.metric-without-data').attr('class', 'metric-with-data');
      $(this).next('div').find('table.metric-without-data').attr('class', 'metrics-table metric-with-data');
      $(this).text("Show summary ALMs").append(children);

    } else {
      // display metric information if there is data
      $(this).next('div').find('tr.metric-with-data').attr('class', 'metric-without-data');
      $(this).next('div').find('table.metric-with-data').attr('class', 'metrics-table metric-without-data');
      $(this).text("Show all ALMs").append(children);
    }

  });
}(document, jQuery));

// Display an error when report metrics page does not have any data to show
$(document).ready(function() {
  if ($(".metrics-left-content").length > 0) {
    if ($(".metrics-left-content .visualizations-list").length == 0) {
      $("#error-message-div")
        .append("<div>The metrics for one or more of the articles requested are not available at this time. Please check back later.</div>")
        .show();
    }
  }
});
