class ReplaceReferencesInArticles < ActiveRecord::Migration[6.0]
  tag :postdeploy
  def change
    add_reference :articles, :user, foreign_key: true
  end
end
