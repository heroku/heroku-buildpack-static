module PathHelper
  def fixtures_path(*path)
    __build_path("../fixtures", *path)
  end

  def buildpack_path(*path)
    __build_path("../../", *path)
  end

  def docker_path(*path)
    __build_path("/docker", *path)
  end
  
  private
  def __build_path(name, *path)
    Pathname.new(File.join(File.dirname(__FILE__), name, *path))
  end
end
