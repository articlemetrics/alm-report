
# Warning: this migration will delete all rows from all tables!
class AddSortOrderToReportDois < ActiveRecord::Migration
  def change
    ReportDoi.delete_all
    Report.delete_all
    add_column :report_dois, :sort_order, :integer, :null => false, :after => :report_id
  end
end
