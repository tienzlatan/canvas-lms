class CreateArticles < ActiveRecord::Migration[6.0]
  tag :predeploy
  def change
    create_table :articles do |t|
      t.belongs_to :account, foreign_key: true
      t.string :title
      t.text :body
      t.timestamps
    end
  end
end
