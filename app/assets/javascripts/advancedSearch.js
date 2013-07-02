// advanced search.  copied from ambra

$('#startDateAsStringId').datepicker({
  changeMonth: true,
  changeYear: true,
  maxDate: 0,
  dateFormat: "yy-mm-dd",
  onSelect: function( selectedDate ) {
    $('#endDateAsStringId').datepicker('option', 'minDate', selectedDate );
  }
});

$('#endDateAsStringId').datepicker({
  changeMonth: true,
  changeYear: true,
  maxDate: 0,
  dateFormat: "yy-mm-dd",
  onSelect: function( selectedDate ) {
    $('#startDateAsStringId').datepicker('option', 'maxDate', selectedDate );
  }
});

var $query_field = $('#queryFieldId');
var $term_el = $('#queryTermDivBlockId');
var $term = $('#queryTermId');
var $date_el = $('#startAndEndDateDivBlockId');
var $date_start = $('#startDateAsStringId');
var $date_end = $('#endDateAsStringId');
var $query = $('#unformattedQueryId');
var is_date;

var isDate = function(field) {
  if (field.val() == 'publication_date' || field.val() == 'received_date' || field.val() == 'accepted_date') {
    is_date = true;
  } else   {
    is_date = false;
  }
};

var changeField = function() {
  if (is_date && $date_el.is(':hidden')) {
    $term_el.hide();
    $date_el.show();
    $term.prop('disabled', true);
    $date_start.prop('disabled', false);
    $date_end.prop('disabled', false);
  } else if (!is_date && $date_el.is(':visible')) {
    $term_el.show();
    $date_el.hide();
    $term.prop('disabled', false);
    $date_start.prop('disabled', true);
    $date_end.prop('disabled', true);
  }
};

$query_field.change(function() {
  isDate($(this));
  changeField();

});

isDate($query_field);
changeField();

var journals_all = $('#journalsOpt_all');
var subject_all = $('#subjectOption_all');
var article_all = $('#articleType_all');

var disableFormEls = function(el) {
  inpts = el.closest('ol').find('.options input');
  inpts.prop('disabled', true);
}

var enableFormEls = function(el) {
  inpts = el.closest('ol').find('.options input');
  inpts.prop('disabled', false);

}

journals_all.change(function() {
  disableFormEls($(this));
});

$('#journalsOpt_slct').change(function() {
  enableFormEls($(this));
});

subject_all.change(function() {
  disableFormEls($(this));
});

$('#subjectOption_some').change(function() {
  enableFormEls($(this));
});

article_all.change(function() {
  disableFormEls($(this));
});

$('#articleType_some').change(function() {
  enableFormEls($(this));
});

if (journals_all.is(':checked')) {
  disableFormEls(journals_all);
}

if (subject_all.is(':checked')) {
  disableFormEls(subject_all);
}

if (article_all.is(':checked')) {
  disableFormEls(article_all);
}

var updateQuery = function() {
  var conj = $(this).val();
  var term_v = $.trim($term.val());
  var query_type = $query_field.val();
  var date_s_v = $date_start.val();
  var date_e_v = $date_end.val();
  var query_v = $query.val();
  var q_string;
  if (is_date) {
    if (date_s_v.length < 1) {
      alert('Please enter a Start Date in the left-hand date field');
      return false;
    }
    if (date_e_v.length < 1) {
      alert('Please enter an End Date in the right-hand date field');
      return false;
    }
    q_string = '[' + date_s_v + 'T00:00:00Z TO ' + date_e_v + 'T23:59:59Z] ';
  } else {
    if (term_v.length < 1) {
      alert('Please enter a Search Term in the text field next to the picklist');
      return false;
    }
    if (term_v.match(/\s/)) {
      q_string = '"' + term_v + '"';
    } else {
      q_string = term_v;
    }
    $term.val('');
  }
  if (query_v.length) {
    q = '(' + query_v + ') ' + conj + ' ' + query_type + ':' + q_string;
  } else if (conj == 'NOT') {
    q = conj + ' ' + query_type + ':' + q_string;
  } else {
    q = query_type + ':' + q_string;
  }
  $query.val(q);
};

$('#queryConjunctionAndId').on('click', updateQuery);
$('#queryConjunctionOrId').on('click', updateQuery);
$('#queryConjunctionNotId').on('click', updateQuery);

$('#clearFiltersButtonId2').on('click', function() {
  journals_all.prop('checked', true);
  subject_all.prop('checked', true);
  article_all.prop('checked', true);
  disableFormEls(journals_all);
  disableFormEls(subject_all);
  disableFormEls(article_all);
});

$('#clearUnformattedQueryButtonId').on('click', function() {
  $query.val('')
});


$('#unformattedSearchFormId').submit(function () {
  var terms = $(this).find('input[name=queryTerm]');
  var sDate = $(this).find('input[name=startDateAsString]');
  var eDate = $(this).find('input[name=endDateAsString]');
  var query = $(this).find('textarea[name=unformattedQuery]');

  if(terms.val().trim().length == 0
    && sDate.val().trim().length == 0
    && eDate.val().trim().length == 0
    && query.val().trim().length == 0) {
    return false;
  }

  //If there is no text in the query field, but text in one of the 'input' fields.
  //Simulate a click to transfer the input into the query field before the submit occurs
  if(query.val().trim().length == 0) {
    $('#queryConjunctionAndId').click();
  }

  return true;
});

$('#quickFind').submit(function () {
  var vol = $(this).find('input[name=volume]');
  var el = $(this).find('input[name=eLocationId]');
  var id = $(this).find('input[name=id]');

  if(vol.val().trim().length > 0) {
    return true;
  }

  if(el.val().trim().length > 0) {
    return true;
  }

  if(id.val().trim().length > 0) {
    return true;
  }

  return false;
});

// To make the checkboxes on the advanced Search page clickable at all the times.
function enableCheckboxes(checkboxId,containerId){

  //Enable corresponding radio button and enable all the checkboxes under that.
  $('#'+containerId).prop('checked',true);
  $('#'+containerId).closest('ol').find('.options input').prop('disabled', false);

  var checkboxes = $("#"+checkboxId);
  //Toggle checkboxes
  checkboxes.prop("checked", !checkboxes.prop("checked"));
}

$('#advancedQueryButtonId').on('click', function() {
  if ($query.val() == null) {
    alert('Please enter a search query');
    return false;
  }
});
