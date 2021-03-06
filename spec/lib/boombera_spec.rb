require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe Boombera do
  let(:db) do
    db = stub(CouchRest::Database)
    CouchRest.stub!(:database! => db)
    db
  end

  let(:content_item) { stub(Boombera::ContentItem) }
  let(:boombera) { Boombera.new('boombera_test') }

  before(:each) do
    Boombera.stub!(:version => '1.2.3')
    Boombera.stub!(:database_version => '1.2.3')
  end

  describe '.new' do
    it 'connects to the specified database on the local couchdb server' do
      CouchRest.should_receive(:database!) \
        .with("my_db") \
        .and_return(db)
      boombera = Boombera.new('my_db')
      boombera.database.should == db
    end

    it 'raises a VersionMismatch error with expected version if the database does not match VERSION' do
      Boombera.stub!(:version => '1.2.2')
      lambda { Boombera.new('boombera_test') }.should \
        raise_error(Boombera::VersionMismatch, "Database expects Boombera 1.2.3")
    end

    it 'raises a VersionMismatch error if the database does not have a boombera_version document' do
      Boombera.stub!(:database_version => nil)
      lambda { Boombera.new('boombera_test') }.should \
        raise_error(Boombera::VersionMismatch, "Database does not specify a Boombera version")
    end
  end

  describe '#put' do
    context "to an existing path" do
      it 'updates and saves the existing content item' do
        Boombera::ContentItem.should_receive(:get_pointer) \
          .with('/foo', db) \
          .and_return(content_item)
        content_item.should_receive(:body=).with('bar')
        content_item.should_receive(:save).and_return(true)
        boombera.put('/foo', 'bar').should == true
      end
    end

    context "to a new path" do
      it 'creates and saves the content item' do
        Boombera::ContentItem.stub!(:get_pointer => nil)
        Boombera::ContentItem.should_receive(:new) \
          .with('/foo', 'bar', db) \
          .and_return(content_item)
        content_item.should_receive(:save).and_return(true)
        boombera.put('/foo', 'bar').should == true
      end
    end
  end

  describe '#get' do
    it 'gets the content item at the specified path from the current database' do
      Boombera::ContentItem.should_receive(:get) \
        .with('/foo', db) \
        .and_return(content_item)
      boombera.get('/foo').should == content_item
    end
  end

  describe '#map' do
    context 'to a new path' do
      before(:each) do
        Boombera::ContentItem.stub!(:get_pointer => nil)
        Boombera::ContentItem.should_receive(:new) \
          .with('/bar', nil, db) \
          .and_return(content_item)
      end

      it 'creates and saves ContentItem as pointer' do
        content_item.should_receive(:map_to).with('/foo')
        content_item.should_receive(:save).and_return(true)
        boombera.map('/bar', '/foo').should == true
      end

      it 'raises an InvalidMapping exception if the source document does not exist' do
        content_item.stub!(:map_to).and_raise(Boombera::InvalidMapping)
        lambda { boombera.map('/bar', '/foo') }.should \
          raise_error(Boombera::InvalidMapping)
      end
    end

    context 'to an existing path' do
      before(:each) do
        Boombera::ContentItem.should_receive(:get_pointer) \
          .with('/bar', db) \
          .and_return(content_item)
      end

      it 'updates ContentItem as pointer' do
        content_item.should_receive(:map_to).with('/foo')
        content_item.should_receive(:save).and_return(true)
        boombera.map('/bar', '/foo').should == true
      end

      it 'raises an InvalidMapping exception if the source document does not exist' do
        content_item.stub!(:map_to).and_raise(Boombera::InvalidMapping)
        lambda { boombera.map('/bar', '/foo') }.should \
          raise_error(Boombera::InvalidMapping)
      end
    end
  end

  describe '.install_design_doc!' do
    context 'when the design doc does not yet exist' do
      it 'creates the design doc on the specified database' do
        CouchRest.should_receive(:database!) \
          .with('boombera_test') \
          .and_return(db)
        db.should_receive(:get) \
          .with('_design/boombera') \
          .and_raise(RestClient::ResourceNotFound)
        db.should_receive(:save_doc) \
          .with(Boombera.design_doc)
        Boombera.install_design_doc!('boombera_test')
      end
    end

    context 'when the design doc already exists' do
      it 'updates the design doc on the specified database' do
        CouchRest.should_receive(:database!) \
          .with('boombera_test') \
          .and_return(db)
        db.should_receive(:get) \
          .with('_design/boombera') \
          .and_return({'_id' => '_design/boombera', '_rev' => '123'})
        db.should_receive(:save_doc).with(Boombera.design_doc.merge('_rev' => '123'))
        Boombera.install_design_doc!('boombera_test')
      end
    end
  end
end

# This is set up as a seperate describe block, because we obviously can't stub
# out .version and .database_version when those are the methods being tested.
describe Boombera do
  describe '.version' do
    it 'returns the current version as specified in the VERSION file' do
      File.should_receive(:read) \
        .with(File.expand_path(File.join(File.dirname(__FILE__), '..', '..',
                                         'VERSION'))) \
        .and_return('1.2.3')
      Boombera.version.should == '1.2.3'
    end
  end

  describe '.database_version' do
    let(:db) { stub(CouchRest::Database) }

    it 'returns the version of Boombera that the database expects to be working with' do
      db.should_receive(:get).with('_design/boombera') \
        .and_return({'gem_version' => '1.2.3'})
      Boombera.database_version(db).should == '1.2.3'
    end

    it 'returns nil if no version is specified in the database' do
      db.stub!(:get).and_raise(RestClient::ResourceNotFound)
      Boombera.database_version(db).should be_nil
    end
  end
end
