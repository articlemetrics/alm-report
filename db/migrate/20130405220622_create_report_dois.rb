class CreateReportDois < ActiveRecord::Migration
  def change
    create_table :report_dois do |t|
      t.string :doi, :limit => 64, :null => false
      t.references :report

      t.timestamps
    end
    add_index :report_dois, :report_id
    add_index :report_dois, :doi, :unique => false
  end
end
