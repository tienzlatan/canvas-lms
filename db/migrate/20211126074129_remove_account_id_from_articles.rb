class RemoveAccountIdFromArticles < ActiveRecord::Migration[6.0]
  tag :postdeploy
  def change
    remove_column :articles, :account_id, :string
  end
end
