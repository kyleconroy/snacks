Sequel.migration do
  up do
    create_table :users do
      primary_key :id
      String :uid, :null => false
      String :name, :null => false
      DateTime :created_at, :null => false
    end
    
    create_table :articles do
      primary_key :id
      String :text, :null => false
      String :title
      String :type, :null => false # either Question or Answer
      DateTime :created_at, :null => false
      DateTime :updated_at
      foreign_key :user_id, :users, :null => false
      foreign_key :article_id, :articles
    end
    # answers_count
    # votes_score

    run "ALTER TABLE articles ADD COLUMN ts_text tsvector;"
    run "CREATE INDEX articles_ts_text_idx ON articles USING gin(ts_text);"
    run "CREATE TRIGGER articles_ts_text_update BEFORE INSERT OR UPDATE
         ON articles FOR EACH ROW EXECUTE PROCEDURE
         tsvector_update_trigger(ts_text, 'pg_catalog.english', text);"
         
    run "ALTER TABLE articles ADD COLUMN ts_title tsvector;"
    run "CREATE INDEX articles_ts_title_idx ON articles USING gin(ts_title);"
    run "CREATE TRIGGER articles_ts_title_update BEFORE INSERT OR UPDATE
        ON articles FOR EACH ROW EXECUTE PROCEDURE
        tsvector_update_trigger(ts_title, 'pg_catalog.english', title);"
         
    create_table :tags do
     primary_key :id
     String :name, :null => false
    end
    #questions_count

    create_table :articles_tags do
     primary_key :id
     foreign_key :tag_id, :tags, :null => false
     foreign_key :article_id, :articles, :null => false
    end

    create_table :votes do
      primary_key :id
      Integer :value
      foreign_key :article_id, :articles, :null => false
      foreign_key :user_id, :users, :null => false
    end

    create_table :comments do
      primary_key :id
      String :text, :null => false
      foreign_key :article_id, :articles, :null => false
      foreign_key :user_id, :users, :null => false
      DateTime :created_at, :null => false
    end
    
    run "ALTER TABLE comments ADD COLUMN ts_text tsvector;"
    run "CREATE INDEX comments_ts_text_idx ON comments USING gin(ts_text);"
    run "CREATE TRIGGER comments_tsvectorupdate BEFORE INSERT OR UPDATE
         ON comments FOR EACH ROW EXECUTE PROCEDURE
         tsvector_update_trigger(ts_text, 'pg_catalog.english', text);"
  end
  
  down do
    drop_table(:articles)
    drop_table(:tags)
    drop_table(:articles_tags)
    drop_table(:users)
    drop_table(:votes)
    drop_table(:comments)
  end
end