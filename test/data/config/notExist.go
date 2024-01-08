package testData

type NonExistingConfigurationFile struct {
    ValidConfigurationFile
}

func (file NonExistingConfigurationFile) IsNotExist(path string) bool {
    return true
}
