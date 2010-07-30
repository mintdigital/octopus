require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Octopus::Proxy do
  let(:proxy) { Octopus::Proxy.new(Octopus.config()) }

  describe "creating a new instance" do    
    it "should initialize all shards and groups" do
      proxy.instance_variable_get(:@shards).keys.to_set.should == [:postgresql_shard, :alone_shard, :aug2011, :canada, :brazil, :aug2009, :russia, :aug2010, :master, :sqlite_shard].to_set
      proxy.instance_variable_get(:@groups).should == {:country_shards=>[:canada, :brazil, :russia], :history_shards=>[:aug2009, :aug2010, :aug2011]}
    end

    it "should initialize the block attribute as false" do
      proxy.block.should be_false
    end    

    it "should initialize replicated attribute as false" do
      proxy.instance_variable_get(:@replicated).should be_false      
    end

    describe "should raise error if you have duplicated shard names" do
      before(:each) do
        set_octopus_env("production_raise_error")                      
      end

      it "should raise the error" do
        lambda { proxy }.should raise_error("You have duplicated shard names!")        
      end
    end

    describe "should initialize just the master when you don't have a shards.yml file" do
      before(:each) do
        set_octopus_env("crazy_enviroment")              
      end

      it "should initialize just the master shard" do
        proxy.instance_variable_get(:@shards).keys.should == [:master]
      end

      it "should not initialize the groups variable" do
        proxy.instance_variable_get(:@groups).should == {}
      end

      it "should not initialize replication" do
        proxy.instance_variable_get(:@replicated).should be_nil
      end
    end
  end

  describe "when you have a replicated enviroment" do
    before(:each) do
      set_octopus_env("production_replicated")      
    end

    it "should have the replicated attribute as true" do
      proxy.instance_variable_get(:@replicated).should be_true
    end

    it "should initialize the list of shards" do
      proxy.instance_variable_get(:@slaves_list).should == ["slave1", "slave2", "slave3", "slave4"]
    end
  end

  describe "when you have a rails application" do
    before(:each) do
      Rails = mock()
      set_octopus_env("octopus_rails")
    end

    it "should initialize correctly octopus common variables for the enviroments" do
      Rails.stub!(:env).and_return('staging')
      Octopus.instance_variable_set(:@rails_env, nil)
      Octopus.config()

      proxy.instance_variable_get(:@replicated).should be_true
      Octopus.enviroments.should == ["staging", "production"] 
    end

    it "should initialize correctly the shards for the staging enviroment" do
      Rails.stub!(:env).and_return('staging')

      proxy.instance_variable_get(:@shards).keys.to_set.should == Set.new([:slave1, :slave2, :master])
    end

    it "should initialize correctly the shards for the production enviroment" do
      Rails.stub!(:env).and_return('production')

      proxy.instance_variable_get(:@shards).keys.to_set.should == Set.new([:slave3, :slave4, :master])
    end

    describe "using the master connection" do
      before(:each) do
        Rails.stub!(:env).and_return('development')        
      end

      it "should use the master connection" do
        user = User.create!(:name =>"Thiago")
        user.name = "New Thiago"
        user.save()
        User.find_by_name("New Thiago").should_not be_nil
      end

      it "should work when using using syntax" do
        user = User.using(:russia).create!(:name =>"Thiago")

        user.name = "New Thiago"
        user.save()
        
        User.using(:russia).find_by_name("New Thiago").should == user
        User.find_by_name("New Thiago").should == user    
      end

      it "should work when using blocks" do
        Octopus.using(:russia) do
          @user = User.create!(:name =>"Thiago")
        end

        User.find_by_name("Thiago").should == @user
      end
      
      it "should work with associations" do
        u = Client.create!(:name => "Thiago")
        i = Item.create(:name => "Item")
        u.items << i
        u.save()
      end
    end

    after(:each) do
      Object.send(:remove_const, :Rails)
      Octopus.instance_variable_set(:@config, nil)
      Octopus.instance_variable_set(:@rails_env, nil)
    end
  end

  describe "returning the correct connection" do
    describe "should return the shard name" do
      it "when current_shard is empty" do
        proxy.shard_name.should == :master        
      end

      it "when current_shard is a single shard" do
        proxy.current_shard = :canada
        proxy.shard_name.should == :canada        
      end

      it "when current_shard is more than one shard" do
        proxy.current_shard = [:russia, :brazil]
        proxy.shard_name.should == :russia              
      end
    end

    describe "should return the connection based on shard_name" do
      it "when current_shard is empty" do
        proxy.select_connection().should == proxy.instance_variable_get(:@shards)[:master].connection()        
      end

      it "when current_shard is a single shard" do
        proxy.current_shard = :canada
        proxy.select_connection().should == proxy.instance_variable_get(:@shards)[:canada].connection()       
      end
    end
  end
end