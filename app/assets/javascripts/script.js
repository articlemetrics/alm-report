// handles the article selection and saving on add-articles.html
jQuery(function(d, $){
  (function(){

    var $list_count = $('.list-count');
    var initial_list_count = parseInt($list_count.text(), 10);
    var preview_list_count = initial_list_count;
    var $preview_list_count_elem = $('.preview-list-count');
    var results_span_pages = ($('.pagination-number').length > 1);
    var select_all_error_msg_visible = false;

    return {
      init : function() {
        // update the header and the sidebar with the current list count
        this.updateListCount(initial_list_count);
        if (initial_list_count == 0) {
          this.disableButton($('#preview-list-submit'));
        }

        // set up event handlers
        $('.check-save-article').on("click", jQuery.proxy(this.checkboxClickHandler, this));
        $('.select-all-articles-link').on("click", { 'mode' : "ADD" }, jQuery.proxy(this.toggleAllArticles, this));
        $('.unselect-all-articles-link').on("click", { 'mode' : "REMOVE" }, jQuery.proxy(this.toggleAllArticles, this));
        $('.reset-btn').on("click", { 'mode' : "REMOVE" }, jQuery.proxy(this.toggleAllArticles, this));

        // We want the preview list count to be accurate even if the user navigates
        // with the back button.  So we always load the current preview list count
        // via ajax.
        $.ajax("/get-article-count", {
          type: "GET",
          cache: false,
          success: jQuery.proxy(function(resp) {
            this.updateListCount(resp);
          }, this)
        });
      },

      // Replaces the preview list counts in the UI with the new value.
      updateListCount : function(new_count) {
        preview_list_count = new_count;

        // update "your list" box in header
        $list_count.text(new_count);

        // update preview list button
        $preview_list_count_elem.val("Preview List (" + new_count + ")");

        // add the correct options depending on the user action
        // remove all children
        $('#your-list-choices').children().remove();
        // add the correct options
        if (new_count == 0) {
          $('#your-list-choices').append('<span>View Report</span><span>Edit List</span>');
        } else {
          $('#your-list-choices').append('<a href="/reports/generate">View Report</a><a href="/preview">Edit List</a>')
        }

        // make sure the next action button is in a correct state
        if (new_count === 0) {
          this.disableButton($('#create-report-submit'));
          this.disableButton($('#preview-list-submit'));
        } else {
          this.enableButton($('#create-report-submit'));
          this.enableButton($('#preview-list-submit'));
        }

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
        if ($checkbox.prop("checked")) {
          if (preview_list_count >= VIZ_LIMIT && preview_list_count < ARTICLE_LIMIT) {
            this.showErrorDialog("viz-limit-error-message");
          } else if (preview_list_count >= ARTICLE_LIMIT) {
            $checkbox.prop("checked", false);
            this.showErrorDialog("article-limit-error-message");
            return;
          }
        }

        // create some data that we want to send to the server
        var ajax_data = {
          // grab the article ID from the checkbox value
          article_ids : [$checkbox.val()],

          // set the "mode" based on what state the checkbox is transitioning to
          // NOTE: this handler runs *after* the checkbox element has been
          // updated so we check the "checked" prop.
          mode : $checkbox.prop("checked") ? "ADD" : "REMOVE"
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
        // var initial_msg = (mode == "ADD") ? "Saving..." : "Removing...";

        // insert the message into the DOM
        // $containers.find('a').after("<span class='updating'>" + initial_msg + "</span>");
        $containers.find('a').after("<span class='updating'><\/span>");
      },

      toggleAllArticles : function(e) {
        if (e.data['mode'] == 'ADD') {

          // Enforce article limit if necessary by only selecting the
          // first articles.
          var max = ARTICLE_LIMIT - preview_list_count;
          var $checkboxes = $(".check-save-article:not(:checked)").slice(0, max);
          if (!select_all_error_msg_visible && $checkboxes.length > 0) {
            var new_count = preview_list_count + $checkboxes.length;
            if (new_count >= VIZ_LIMIT && new_count < ARTICLE_LIMIT) {
              this.showErrorDialog("viz-limit-error-message");
              select_all_error_msg_visible = true;
            } else if (new_count >= ARTICLE_LIMIT) {
              if (max == 0) {
                this.showErrorDialog("article-limit-error-message");
              } else {
                var message = $("#article-limit-error-message").html();
                message = "Only the first " + max + " of the results have been added.  " + message;
                $('#partial-select-all-error-message').html(message);
                this.showErrorDialog("partial-select-all-error-message");
              }
              select_all_error_msg_visible = true;
            }
          }
          already_clicked_select_all = true;
        } else {
          var $checkboxes = $(".check-save-article:checked");
        }
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
          checkbox.prop("checked", (e.data['mode'] == 'ADD'));

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
          this.updateServer(ajax_data, $checkboxes, $containers, true);
        }
      },

      updateServer : function(ajax_data, $checkboxes, $containers, toggle_all) {
        toggle_all = toggle_all || false;

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
          complete : jQuery.proxy(this.ajaxResponseHandler, this, ajax_data.mode,
              $checkboxes, $containers, toggle_all)
        });
      },

      // expects a jquery collections of checkboxes and containers
      ajaxResponseHandler : function(mode, $checkboxes, $containers, toggle_all, xhr, status) {
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
              text : (mode == "ADD") ? "Saved" : "Removed",
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
        if (preview_list_count === 0) {
          this.disableButton($('#create-report-submit'));
          this.disableButton($('#preview-list-submit'));
        } else {
          this.enableButton($('#create-report-submit'));
          this.enableButton($('#preview-list-submit'));
        }

        // Show select all/unselect all messaging if applicable.
        if (!error_occurred && toggle_all) {

          // show "select all articles across all pages" message if this
          // result set spans multiple pages and we've just checked all the
          // articles on this page
          if (results_span_pages && (selected_articles_count == RESULTS_PER_PAGE)) {
            this.showSelectAll();
          } else if (json_resp.delta < 0) {
            this.showUnselectAll(-json_resp.delta);
          }
        }

      },

      // Removes any "select all" or "unselect all" message from the add articles page.
      clearSelectAllMessage : function(message) {
        if ($('.select-articles-message').is(':visible')) {
          $('#select-articles-message-text').html('');
          $('#select-all-articles-message-text').html('');
          $('.select-articles-message').addClass('invisible');
        }
      },

      // Shows the "select all" message on the add articles page.
      showSelectAll : function() {
        this.clearSelectAllMessage();
        $('#select-articles-message-text').html(
            'The ' + RESULTS_PER_PAGE + ' articles on this page have been selected.');
        var additional_count = Math.min(ARTICLE_LIMIT, search_total_found) - preview_list_count;
        if (additional_count > 0) {
          $('#select-all-articles-message-text').html(
              ' <a href="#" id="select_all_searchresults">Select the remaining '
              + additional_count + ' articles</a>.');
        } else {
          $('#select-all-articles-message-text').hide();
        }
        $('.select-articles-message').removeClass('invisible');
        $('#select_all_searchresults').on('click',
            jQuery.proxy(this.selectAllSearchResults, this));
      },

      // Shows the "unselect all" message on the add articles page.
      showUnselectAll : function(unselect_count) {

        // We use the same DOM components as showSelectAll above.  Don't let that
        // confuse you...
        this.clearSelectAllMessage();
        $('#select-articles-message-text').html(
            'The ' + unselect_count + ' articles on this page have been unselected.');
        if (preview_list_count > 0) {
          $('#select-all-articles-message-text').html(
              '<a href="#" id="select_all_searchresults">Unselect all articles</a>.');
        } else {
          $('#select-all-articles-message-text').hide();
        }
        $('.select-articles-message').removeClass('invisible');
        $('#select_all_searchresults').on('click', jQuery.proxy(function(e) {
          $.ajax('/start-over', {
            type: 'GET',
            success: jQuery.proxy(function(e) {
              this.clearSelectAllMessage();
              this.updateListCount(0);
            }, this)
          })
        }, this));
      },

      // Changes the visual appearance of one of the styled submit buttons
      // in the UI and prevents it from being activated.
      disableButton : function($button) {
        $button.addClass('disabled-submit-btn');
        $button.attr('disabled', 'disabled');
      },

      // Enables a submit button that was previously disabled through disableButton.
      enableButton : function($button) {
        $button.removeClass('disabled-submit-btn');
        $button.removeAttr('disabled');
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
        $("#gray-out-screen").css({
          opacity: 0.7,
          "width": $(document).width(),
          "height": $(document).height()
        });
        $("body").css({"overflow": "hidden"});
        $("#select-all-spinner").css({"display": "block"});

        $.ajax("/select-all-search-results", {
          type: "GET",

          // Unless we set this header, rails will silently refuse to save anything
          // to the session!
          beforeSend: function(xhr) {
              xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))
              },
          complete: jQuery.proxy(this.selectAllSearchResultsResponseHandler, this),
          data: window.location.search
        });
      },

      selectAllSearchResultsResponseHandler : function(xhr, status) {
        $("#gray-out-screen").hide();
        $("#select-all-spinner").hide();
        $(".select-articles-message").addClass('invisible');

        var json_resp = $.parseJSON(xhr.responseText);
        if (status == "success" && json_resp.status == "success") {
          var $unchecked_checkboxes = $(".check-save-article:not(:checked)");
          $unchecked_checkboxes.prop("checked", true);
          this.incrementListCount(json_resp.delta);
          if (!select_all_error_msg_visible && preview_list_count > VIZ_LIMIT) {
            this.showErrorDialog("viz-limit-error-message");
            select_all_error_msg_visible = true;
          }
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
    var container_width = $('.container.main').width();

    function scrollHandler() {
      // fix the position of the .aside_container if the viewport has
      // scrolled 40 pixels beyond the height of the header
      if ( $(window).scrollTop() > ($('.section.header').height() + 40) ) {

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
      var field_name = "doi-pmid-" + i;
      fields_html += [
        '<div class="input-holder">',
          '<label for="' + field_name + '">DOI/PMID</label>',
          '<div>',
            '<input type="text" name="' + field_name + '" id="' + field_name + '" />',
          '</div>',
        '</div>'
      ].join("\n");
    }

    // add all the markup in one fell swoop
    // "-2" because the last .input-holder is for the submit buttons and
    // we want the new fields before it.
    $(".doi-pmid-form .input-holder").eq(-2).after(fields_html);
    $('[id^=doi-pmid-]').on("change", doiPmidInputOnChange);
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
    $parent_div.append('<span class="doi-pmid-remove">Remove</span>');
    $parent_div.append('<p class="error-message error-color">' + error_message + '</p>');

    // Need to re-add this listener since we recreated the element above.
    $('.doi-pmid-remove').on("click", dismissDoiPmidErrors);
  }
};


// Onchange handler for text fields on the "Find Articles by DOI/PMID" page.
// Performs validation to ensure the values are valid DOIs or PMIDs identifing
// PLOS articles.
var doiPmidInputOnChange = function() {
  var input_element = $(this)[0];
  var value = $.trim(input_element.value);

  // Assume for now that anything that looks like an int is a PMID.  We can't
  // use parseInt here, since it will accept a value that only *starts* with
  // an integer.  So "10.1371/journal.pbio.0000001" == 10.
  var pmid = null;
  if (/^[0-9]+$/.test(value)) {
    pmid = Number(value);
  }
  var doi = null;

  // There are two types of PLOS DOIs that we have to handle differently.  Currents
  // DOIs are not in solr, so we don't want to attempt to validate against that
  // if it looks like a currents DOI (which have very little structure).
  var is_currents_doi = false;
  if (pmid === null) {
    var match = /(info:)?(doi\/)?(10\.1371\/journal\.p[a-z]{3}\.\d{7})/.exec(value);
    if (match != null && match[3] != null) {
      doi = match[3];
    } else {
      var match = /(info:)?(doi\/)?(10\.1371\/\S+)/.exec(value);
      if (match != null && match[3] != null) {
        doi = match[3];
        is_currents_doi = true;
      } else {
        highlightDoiPmidError(input_element, 'This DOI/PMID is not a PLOS article');
      }
    }
  }

  if (is_currents_doi) {

    // Looks like a valid currents doi.  Remove any previous error message.
    dismissDoiPmidFieldError($(input_element).parent('.error-holder'));
  } else if (pmid !== null || doi !== null) {

    // Validate ID against solr.  We need to make a jsonp request to get around the
    // same-origin policy.
    if (pmid !== null) {
      var query = 'pmid:"' + pmid + '"';
    } else {
      var query = 'id:"' + doi + '"';
    }
    $.ajax('http://api.plos.org/search', {
        type: 'GET',
        dataType: 'jsonp',
        data: {wt: 'json', q: query, fl: 'id', facet: 'false'},
        jsonp: 'json.wrf',
        success: function(resp) {
          if (resp.response.numFound >= 1) {

            // Remove any previous error message.
            dismissDoiPmidFieldError($(input_element).parent('.error-holder'));
          } else {
            highlightDoiPmidError(input_element, 'This paper could not be found');
          }
        }
    });
  }
};


jQuery(function(d, $){
  $('[id^=doi-pmid-]').on("change", doiPmidInputOnChange);
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
    var query = queryString.parse(location.search);
    query.sort = sort_param;
    location.search = queryString.stringify(query);
  });
}(document, jQuery));


// Event handler for "Show all ALMs" on the report metrics page
jQuery(function(d, $){
  $('.show-all-alms-link').click(function() {

    var linkText = $(this).text();
    var children = $(this).children();

    if (linkText.toLowerCase() === 'show all alms') {
      // display all the metric information with zero values
      $(this).parent().next('div').find('tr.metric-without-data').attr('class', 'metric-with-data');
      $(this).parent().next('div').find('table.metric-without-data').attr('class', 'metrics-table metric-with-data');
      $(this).text("Show summary ALMs").append(children);
      $(this).children("span").attr('class', 'arrow-up');

    } else {
      // display metric information if there is data
      $(this).parent().next('div').find('tr.metric-with-data').attr('class', 'metric-without-data');
      $(this).parent().next('div').find('table.metric-with-data').attr('class', 'metrics-table metric-without-data');
      $(this).text("Show all ALMs").append(children);
      $(this).children("span").attr('class', 'arrow-down');
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


// Handles subject category autocomplete functionality on the search page.  This code
// is largely borrowed from ambra, where we do something similar.  See
// webapp/src/main/webapp/javascript/user.js.

/*
 * jQuery UI Autocomplete HTML Extension
 *
 * Copyright 2010, Scott González (http://scottgonzalez.com)
 * Dual licensed under the MIT or GPL Version 2 licenses.
 *
 * http://github.com/scottgonzalez/jquery-ui-extensions
 */

// HTML extension to autocomplete borrowed from
// https://github.com/scottgonzalez/jquery-ui-extensions/blob/master/autocomplete/jquery.ui.autocomplete.html.js

(function($) {

  var proto = $.ui.autocomplete.prototype,
    initSource = proto._initSource;

  function filter(array, term) {
    var matcher = new RegExp($.ui.autocomplete.escapeRegex(term), "i");
    return $.grep(array, function(value) {
      return matcher.test($("<div>").html(value.label || value.value || value).text());
    });
  }

  $.extend(proto, {
    _initSource: function() {
      if ($.isArray(this.options.source)) {
        this.source = function(request, response) {
          response(filter( this.options.source, request.term));
        };
      } else {
        initSource.call(this);
      }
    },

    _renderItem: function(ul, item) {
      return $("<li></li>")
        .data("item.autocomplete", item)
        .append($("<a style=\"line-height: "
          + (item.value ? 0.9 : 2)
          + "; font-size: 12px;\"></a>")
          [item.type == "html" ? "html" : "text"](item.label))
        .appendTo(ul);
    }
  });

})(jQuery);


$(".subject-autocomplete[type='text']").autocomplete({
  source: function(entry, response) {
    $.ajax("http://api.plos.org/terms", {
        type: 'GET',
        dataType: 'jsonp',
        data:{
          "terms": "true",
          "terms.fl" : "subject_facet",
          "terms.regex" : ".*" + entry.term + ".*",
          "terms.limit" : 10,
          "terms.sort" : "index",
          "terms.regex.flag" : "case_insensitive",
          "wt": "json"
        },
        jsonp: 'json.wrf',
        success: function (data) {
          var options = [];

          // Every other element is what we want
          for(var i = 0; i < data.terms.subject_facet.length; i = i + 2) {
            options.push({
                label: data.terms.subject_facet[i].replace(new RegExp("(" + entry.term + ")", "gi"), "<strong>$1</strong>"),
              type: "html",
              value: data.terms.subject_facet[i]
            });
          }
          response(options);
        },
        error: function (xOptions, textStatus) {
          console.log(textStatus);
        }
    });
  }
});

// End subject category autocomplete.


// Event handler for downloading visualization
jQuery(function(d, $){
  $('#download_viz').click(function() {

    window.print();

  });
}(document, jQuery));

// Onclick handler for downloading report metrics.  Pops up a confirmation dialog
// if there are enough articles in the report that the operation might be slow.
jQuery(function(d, $){
  $('#metrics-download-link').click(function(e) {
    var article_count = parseInt($('.list-count').text(), 10);
    if (article_count > VIZ_LIMIT) {
      var msg = 'Downloading metrics data for ' + article_count
          + ' articles can be quite slow, and take up to several minutes.  Are you sure you want to proceed?'
      var cont = confirm(msg);
      if (cont) {
        return true;
      } else {
        e.preventDefault();
      }
    }
  });
}(document, jQuery));

// Onclick handler for pseudo-links that aren't actually <a>'s.  This is sometimes
// easier than dealing with CSS issues.
jQuery(function(d, $) {
  $('.nona-link').click(function() {
    window.location.href = $(this).data('href');
  });
}(document, jQuery));
