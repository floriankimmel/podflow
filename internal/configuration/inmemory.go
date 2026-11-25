package config

// InMemory is a configuration that lives only for one run. It is used when
// the caller builds the configuration instead of reading a config file.
type InMemory struct {
	Config Configuration
}

func (m *InMemory) Read(string) (Configuration, error) { return m.Config, nil }
func (m *InMemory) Path() (string, error)              { return "in-memory", nil }
func (m *InMemory) DoesNotExist(string) bool           { return false }
func (m *InMemory) Write(config Configuration) error {
	m.Config = config
	return nil
}
