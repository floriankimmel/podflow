package testdata

type NonExistingConfigurationFile struct {
	ValidConfigurationFile
}

func (file NonExistingConfigurationFile) DoesNotExist(path string) bool {
	return true
}
